#!/usr/bin/env bash

source run-env.sh
linux_version=`gawk -F= '/^NAME/{print $2}' /etc/os-release`
echo $linux_version
for ((i=1;i<=$CONTAINER_COUNT;i++)); do

    echo "Starting container ${i} ..."
    if grep -q Ubuntu <<<$linux_version; then
        docker run  --log-opt splunk-gzip-level=$GZIP_LEVEL --log-opt tag="{{.Name}}/{{.FullID}}" --log-opt splunk-gzip=$GZIP --log-opt splunk-format=$FORMAT --log-opt splunk-source=$SPLUNK_SOURCE --log-opt splunk-sourcetype=$SPLUNK_SOURCETYPE -d -e MSG_COUNT=$DGA_MSG_COUNT -e MSG_SIZE=$DGS_MSG_SIZE -e EPS=$DGA_EPS luckyj5/docker-datagen

    else
        docker run --log-driver=splunk-log-plugin --log-opt splunk-gzip-level=$GZIP_LEVEL --log-opt tag="{{.Name}}/{{.FullID}}" --log-opt splunk-gzip=$GZIP --log-opt splunk-format=$FORMAT --log-opt splunk-url=$SPLUNK_HOST --log-opt splunk-token=$SPLUNK_TOKEN --log-opt splunk-source=$SPLUNK_SOURCE --log-opt splunk-sourcetype=$SPLUNK_SOURCETYPE --log-opt splunk-insecureskipverify=true -d -e MSG_COUNT=$DGA_MSG_COUNT -e MSG_SIZE=$DGS_MSG_SIZE -e EPS=$DGA_EPS luckyj5/docker-datagen
    fi
done
