.PHONY: \
	setup-docker build run recollect-data reload-data download \
	collect templates pipeline export-kibana import-kibana commit-containers \
	tag-gcr push-gcr tag-hub push-hub clean deploy-gcr depoy-hub tag-treescale \
	push-treescale deploy-treescale extrapolate extract pdf-extract

OS=$(shell uname -s)
ES_STACK=elastic-stack
CSV_DATA_DIR=data/csv/
PDF_DATA_DIR=data/pdf/
CHAPECO_DATA_DIR=$(PDF_DATA_DIR)/chapeco/
ifndef PROJECT_NAME
PROJECT_NAME=$(shell basename `pwd`)
endif

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
	PROJECT_NAME=$(PROJECT_NAME) make -C $(ES_STACK) setup
	pip install -r requirements.txt
	make setup-docker
	make build
	make download
	make extract
	make extrapolate

build: pipeline
	PROJECT_NAME=$(PROJECT_NAME) make -C $(ES_STACK) build
	docker-compose build

repository:
	docker-compose run downloader \
		curl -XPUT http://localhost:9200/_snapshot/backup -d '{"type": "fs", "settings": {"location": "/snapshots"}}' -H 'Content-Type: application/json'

backup: repository
	docker-compose run downloader \
		curl -XPUT "http://localhost:9200/_snapshot/backup/snapshot_$(shell date +%s)?wait_for_completion=true"

run: $(CSV_DATA_DIR) setup-docker collect templates pipeline 	
	PROJECT_NAME=$(PROJECT_NAME) make -C $(ES_STACK) run

stop:
	PROJECT_NAME=$(PROJECT_NAME) make -C $(ES_STACK) stop

update-data: clean download extract extrapolate reload-data run

clean:
	-rm -rf $(CSV_DATA_DIR)/*
	-rm -rf $(PDF_DATA_DIR)/*
	-rm -f $(ES_STACK)/data/*

reload-data:
	PROJECT_NAME=$(PROJECT_NAME) make -C $(ES_STACK) down
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
	docker-compose run scrapper python scrapper/scrape.py /input-data/pdf/chapeco /output-data/chapeco.csv

$(ES_STACK)/data/%-extra.csv: $(ES_STACK)/data/%.csv
	docker-compose run extrapolation python /extrapolation/extrapolate.py /data/`basename $<` /data/`basename $@` --prior 60 --after 30 --order 2

$(ES_STACK)/data/%.csv: $(CSV_DATA_DIR)/%.csv.gz
	gunzip -c $< > $@

templates:
	cp elasticsearch/index-templates/* $(ES_STACK)/index-templates/

pipeline:
	cp logstash/logstash.conf $(ES_STACK)/stack/custom/logstash-data-loader/files/usr/share/logstash/pipeline/logstash.conf

export-kibana:
	-rm -f kibana/data/.kibana*
	-docker-compose run elasticdump \
		elasticdump --input http://localhost:9200/.kibana_1 --output /kibana/data/.kibana_1.mapping --type=mapping
	-docker-compose run elasticdump \
		elasticdump --input http://localhost:9200/.kibana_1 --output /kibana/data/.kibana_1.data --type=data

import-kibana:
	-docker-compose run elasticdump \
		elasticdump --output http://localhost:9200/.kibana_1 --input /kibana/data/.kibana_1.mapping --type=mapping
	-docker-compose run elasticdump \
		elasticdump --output http://localhost:9200/.kibana_1 --input /kibana/data/.kibana_1.data --type=data
