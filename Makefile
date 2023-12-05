new_parse_all: parse

old_parse_all: generate_parser parse

parse:
	bash parse_parallel.bash

parse_multi_in_makefile:
	# bash parse_parallel.bash
	@for dir in cassandra_data_history/* ; do \
		./hexdump.bash $$dir/sina_test/*/me-1-big-Data.db > $$dir/bytes.txt ; \
		bash parse.bash $$dir | tee $$dir/result.txt ; \
	done

test:
	poetry run python test.py

generate_parser: vlq_base128_le.ksy vlq_base128_be.ksy
	kaitai-struct-compiler --target python --opaque-types=true sstable-data-2.0.ksy

all: populate_db old_parse_all

.PHONY: populate_db
populate_db: clean cass_zig
	make populate_rows
	docker stop cass_zig

	mkdir -p cassandra_data_history/
	$(eval data_dir := cassandra_data_history/$(shell date "+%Y-%m-%d_%H-%M-%S-%N"))
	cp -rp cassandra_data/data $(data_dir)
	cp populate_rows.cql $(data_dir)

# ====

vlq_base128_le.ksy:
	wget https://raw.githubusercontent.com/kaitai-io/kaitai_struct_formats/master/common/vlq_base128_le.ksy

vlq_base128_be.ksy:
	wget https://raw.githubusercontent.com/kaitai-io/kaitai_struct_formats/master/common/vlq_base128_be.ksy

.PHONY: cass_zig
cass_zig:
	docker run -d \
		-v $(PWD)/cassandra-3.0.yaml:/etc/cassandra/cassandra.yaml \
		-v $(PWD)/:/root/work:ro \
		-v $(PWD)/cassandra_data:/var/lib/cassandra \
		--name cass_zig cassandra:3.0 || docker start cass_zig

.PHONY: populate_rows
populate_rows:
	docker exec -it cass_zig /root/work/startup.bash

.PHONY: stop
stop:
	docker stop -f cass_zig

.PHONY: clean
clean:
	docker rm -f cass_zig
	sudo rm -rf ./cassandra_data

.PHONY: bash
bash:
	docker exec -it cass_zig bash

.PHONY: logs
logs:
	docker logs -f cass_zig

.PHONY: consume
consume:
	docker run -v $(PWD)/:/src/ -v $(PWD)/cdc_raw/:/cdc_raw/ --rm -it groovy:latest bash
	# docker run -v $(PWD)/:/src/ --rm -it groovy:latest groovy /src/read-commitlog.groovy

