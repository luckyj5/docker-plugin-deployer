#!/usr/bin/env bash


screen -S proc_monitor -m -d /home/ec2-user/proc_monitor/python proc_monitor.py &
source run-env.sh
for ((i=1;i<=$CONTAINER_COUNT;i++)); do

    echo "Starting container ${i} ..."
        docker run --log-driver=splunk-log-plugin --log-opt splunk-gzip-level=$GZIP_LEVEL --log-opt tag="{{.Name}}/{{.FullID}}" --log-opt splunk-gzip=$GZIP --log-opt splunk-format=$FORMAT --log-opt splunk-url=$SPLUNK_HOST --log-opt splunk-token=$SPLUNK_TOKEN --log-opt splunk-source=$SPLUNK_SOURCE --log-opt splunk-sourcetype=$SPLUNK_SOURCETYPE --log-opt splunk-insecureskipverify=true -d -e MSG_COUNT=$DGA_MSG_COUNT -e MSG_SIZE=$DGS_MSG_SIZE -e EPS=$DGA_EPS luckyj5/docker-datagen
        screen -S proc_monitor -m -d python /home/ec2-user/proc_monitor/proc_monitor.py &
done
