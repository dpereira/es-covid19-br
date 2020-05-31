.PHONY: \
	setup-docker build run recollect-data reload-data download \
	collect templates pipeline export-kibana import-kibana commit-containers \
	tag-gcr push-gcr tag-hub push-hub clean deploy-gcr depoy-hub tag-treescale \
	push-treescale deploy-treescale extrapolate extract pdf-extract

OS=$(shell uname -s)
DATA=covid19-br
ES_STACK=elastic-stack
CSV_DATA_DIR=data/csv/
PDF_DATA_DIR=data/pdf/
CHAPECO_DATA_DIR=$(PDF_DATA_DIR)/chapeco/


%: export USER_ID:=$(shell echo -n `id -u`:`id -g`)

$(CSV_DATA_DIR):
	mkdir -p $(CSV_DATA_DIR)

$(PDF_DATA_DIR):
	mkdir -p $(PDF_DATA_DIR)

$(CHAPECO_DATA_DIR): $(PDF_DATA_DIR)
	mkdir -p $(CHAPECO_DATA_DIR)

setup-docker:
ifeq "$(OS)" "Linux"
	make -C $(ES_STACK) setup_vm_max_map_count
endif

setup:
	git submodule update --init
	make -C $(ES_STACK) setup
	make setup-docker
	make build
	make download

build: pipeline
	make -C $(ES_STACK) build
	docker-compose build

build-data:
	make -C $(DATA) docker-build

repository:
	docker-compose run downloader \
		curl -XPUT http://elasticsearch:9200/_snapshot/backup -d '{"type": "fs", "settings": {"location": "/snapshots"}}' -H 'Content-Type: application/json'

backup: repository
	docker-compose run downloader \
		curl -XPUT "http://elasticsearch:9200/_snapshot/backup/snapshot_$(shell date +%s)?wait_for_completion=true"

run: $(CSV_DATA_DIR) setup-docker collect templates pipeline 	
	make -C $(ES_STACK) run

stop:
	make -C $(ES_STACK) stop

update-data: clean download extract extrapolate reload-data run

recollect-data: build-data
	make -C $(ES_STACK) down
	make clean
	make collect
	make build

clean:
	-rm -rf $(CSV_DATA_DIR)/*
	-rm -rf $(PDF_DATA_DIR)/*
	-rm -f $(ES_STACK)/data/*

reload-data:
	make -C $(ES_STACK) down
	make build

download-brasil-io: $(CSV_DATA_DIR)
	docker-compose run downloader \
		curl https://data.brasil.io/dataset/covid19/boletim.csv.gz --output /$(CSV_DATA_DIR)/boletim.csv.gz
	docker-compose run downloader \
		curl https://data.brasil.io/dataset/covid19/obito_cartorio.csv.gz --output /$(CSV_DATA_DIR)/obito_cartorio.csv.gz
	docker-compose run downloader \
		curl https://data.brasil.io/dataset/covid19/caso.csv.gz --output /$(CSV_DATA_DIR)/caso.csv.gz

download-chapeco-sms: $(CHAPECO_DATA_DIR)
	docker-compose run downloader \
		wget -c --content-disposition -nd  -r -l 1 \
		-R 'seguranca*' -A DocumentoArquivo,pdf \
		https://www.chapeco.sc.gov.br/documentos/54/documentoCategoria \
		-P /data/pdf/chapeco/

download: download-brasil-io download-chapeco-sms

collect: $(ES_STACK)/data/caso.csv $(ES_STACK)/data/boletim.csv $(ES_STACK)/data/obito_cartorio.csv

extrapolate: $(ES_STACK)/data/caso-extra.csv

extract: pdf-extract

pdf-extract:
	docker-compose run scrapper python scrapper/scrap.py /input-data/pdf/chapeco /output-data/chapeco.csv

$(CSV_DATA_DIR)/%.gz: $(CSV_DATA_DIR)
	-make -C $(DATA) docker-run

$(ES_STACK)/data/%-extra.csv: $(ES_STACK)/data/%.csv
	docker-compose run extrapolation python /extrapolation/extrapolate.py /data/`basename $<` /data/`basename $@` --prior 60 --after 30 --order 2

$(ES_STACK)/data/%.csv: $(CSV_DATA_DIR)/%.csv.gz
	gunzip -c $< > $@

templates:
	cp index-templates/* $(ES_STACK)/index-templates/

pipeline:
	cp logstash/logstash.conf $(ES_STACK)/stack/custom/logstash-data-loader/files/usr/share/logstash/pipeline/logstash.conf

kibana:
	mkdir kibana

export-kibana: kibana
	-rm -f kibana/.kibana*
	-docker-compose run elasticdump \
		elasticdump --input http://localhost:9200/.kibana_1 --output /kibana/.kibana_1.mapping --type=mapping
	-docker-compose run elasticdump \
		elasticdump --input http://localhost:9200/.kibana_1 --output /kibana/.kibana_1.data --type=data

import-kibana:
	-docker-compose run elasticdump \
		elasticdump --output http://localhost:9200/.kibana_1 --input /kibana/.kibana_1.mapping --type=mapping
	-docker-compose run elasticdump \
		elasticdump --output http://localhost:9200/.kibana_1 --input /kibana/.kibana_1.data --type=data

commit-containers:
	docker commit stack_elasticsearch_7.6.2 stack_elasticsearch_7.6.2
	docker commit stack_kibana_7.6.2 stack_kibana_7.6.2

tag-gcr:
	docker tag stack_elasticsearch_7.6.2 gcr.io/es-covd19-br/stack_elasticsearch_7.6.2
	docker tag stack_kibana_7.6.2 gcr.io/es-covd19-br/stack_kibana_7.6.2

tag-hub:
	docker tag stack_elasticsearch_7.6.2 diegop/stack_elasticsearch_7.6.2
	docker tag stack_kibana_7.6.2 diegop/stack_kibana_7.6.2

tag-treescale:
	docker tag stack_kibana_7.6.2 repo.treescale.com/dpereira/es-covid19-br/stack_kibana_7.6.2
	docker tag stack_elasticsearch_7.6.2 repo.treescale.com/dpereira/es-covid19-br/stack_elasticsearch_7.6.2

push-gcr:
	docker push gcr.io/es-covd19-br/stack_elasticsearch_7.6.2
	docker push gcr.io/es-covd20-br/stack_kibana_7.6.2

push-hub:
	docker push diegop/stack_kibana_7.6.2
	docker push diegop/stack_elasticsearch_7.6.2

push-treescale:
	docker push repo.treescale.com/dpereira/es-covid19-br/stack_kibana_7.6.2
	docker push repo.treescale.com/dpereira/es-covid19-br/stack_elasticsearch_7.6.2

deploy-gcr: commit-containers tag-gcr push-gcr

deploy-hub: commit-containers tag-hub push-hub

deploy-treescale: commit-containers tag-treescale push-treescale
