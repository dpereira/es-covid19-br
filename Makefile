
DATA=covid19-br
ES_STACK=elastic-stack
DATA_OUTPUT_DIR=data/output

setup:
	git submodule update --init
	make -C $(ES_STACK) setup
	make -C $(ES_STACK) setup_vm_max_map_count
	npm install elasticdump

build: pipeline
	make -C $(DATA) docker-build
	make -C $(ES_STACK) build

run: collect templates pipeline
	make -C $(ES_STACK) run

recollect-data:
	-curl -XDELETE http://localhost:9200/caso
	-curl -XDELETE http://localhost:9200/boletim
	-curl -XDELETE http://localhost:9200/obito_cartorio
	make -C $(ES_STACK) down
	make build
	-rm -rf $(DATA_OUTPUT_DIR)/*
	-rm -f $(ES_STACK)/data/*
	make run

reload-data:
	make -C $(ES_STACK) down
	make build
	make run

collect: $(ES_STACK)/data/boletim.csv $(ES_STACK)/data/caso.csv $(ES_STACK)/data/obito_cartorio.csv

data/output/%.gz:
	make -C $(DATA) docker-run
	sudo chown -R ${USER} $(DATA_OUTPUT_DIR)

$(ES_STACK)/data/%.csv: $(DATA_OUTPUT_DIR)/%.csv.gz
	gunzip -c $< > $@

templates:
	cp index-templates/* $(ES_STACK)/index-templates/

pipeline:
	cp logstash/logstash.conf $(ES_STACK)/stack/custom/logstash-data-loader/files/usr/share/logstash/pipeline/logstash.conf

kibana:
	mkdir kibana

export-kibana: kibana
	-rm -f kibana/*
	node_modules/elasticdump/bin/elasticdump --input http://localhost:9200/.kibana_1 --output kibana/.kibana_1.mapping --type=mapping
	node_modules/elasticdump/bin/elasticdump --input http://localhost:9200/.kibana_1 --output kibana/.kibana_1.data --type=data

import-kibana:
	node_modules/elasticdump/bin/elasticdump --output http://localhost:9200/.kibana_1 --input kibana/.kibana_1.mapping --type=mapping
	node_modules/elasticdump/bin/elasticdump --output http://localhost:9200/.kibana_1 --input kibana/.kibana_1.data --type=data
