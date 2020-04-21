
DATA=covid19-br
ES_STACK=elastic-stack
DATA_OUTPUT_DIR=data/output

setup:
	make -C $(ES_STACK) setup
	make -C $(ES_STACK) setup_vm_max_map_count

build: pipeline
	make -C $(DATA) docker-build
	make -C $(ES_STACK) build

run: collect templates pipeline
	make -C $(ES_STACK) run

reload-data:
	-curl -XDELETE http://localhost:9200/caso
	-curl -XDELETE http://localhost:9200/boletim
	-curl -XDELETE http://localhost:9200/obito_cartorio
	make -C $(ES_STACK) down
	make build
	-rm -rf $(DATA_OUTPUT_DIR)/*
	-rm -f $(ES_STACK)/data/*
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
