#!/bin/bash

HOST=$1
ACTION=$2
INDICES=`curl "http://$HOST:9200/_cat/indices?h=i" | grep 'kibana'`

for i in $INDICES;
do
    echo; echo $ACTION $i '...'
    curl -XPOST http://$HOST:9200/$i/_$ACTION;
done;
