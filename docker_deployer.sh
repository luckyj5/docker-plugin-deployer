#!/bin/bash

# set -x

# Configuration file
DOCKERLAB=docker.lab
CRED=cred.lab

USERNAME=ec2-user
CREDFILE=cred.lab

PROC_MONITOR=/home/ec2-user/proc_monitor
DOCKER_VERSION=17.12.1-ce
DOCKER_RELEASE="stable"
DOCKER_COMPOSE_VERSION=1.18.0

curdir=`pwd`

execute_remote_cmd() {
    ip="$1"
    cmd="$2"
    sudo="$3"

    #if [[ -z "${sudo}" ]]; then
    #    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=quiet -i ${CREDFILE} $USERNAME@${ip} "${cmd}"
    #else
        # sudo
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=quiet -i ${CREDFILE} $USERNAME@${ip} -t -t "${cmd}"
    #fi
}

print_msg() {
    datetime=`date "+%Y-%m-%d %H:%M:%S"`
    echo "$datetime: $1"
}

read_user_cred() {
    i=0
    while IFS='' read -r line || [[ -n $line ]]; do
        setting=`echo $line | grep -v \#`
        if [[ "$setting" != "" ]]; then
            ((i++))
            if [[ $i == 1 ]]; then
                USERNAME=$setting
            elif [[ $i == 2 ]]; then
                CREDFILE=$setting
            fi
        fi
    done < ${CRED}
}


run_container() {
    if [[ "$1" == "" ]]; then
        for ip in `cat ${DOCKERLAB} | grep -v \# | awk -F\| '{print $1}'`
        do
            if [ "${ip}" == "" ]; then
                continue
            fi

            rsync -raz -e "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=quiet -i $CREDFILE" --exclude=macos ${curdir}/run* $USERNAME@${ip}:~/
            execute_remote_cmd "${ip}" "sudo chmod +x run*"
            print_msg "Running data-gen containers on  ${ip}"
            execute_remote_cmd "${ip}" "./run.sh"
        done
    else

        print_msg "Docker doesn't exist on $1"
    fi

}

install_docker() {

    if [[ "$1" == "" ]]; then
        for ip in `cat ${DOCKERLAB} | grep -v \# | awk -F\| '{print $1}'`
        do
            if [ "${ip}" == "" ]; then
                continue
            fi

            print_msg "Installing docker on  ${ip}"
            execute_remote_cmd "${ip}" "sudo yum update -y; sudo yum install -y docker; sudo service docker start; sudo usermod -a -G docker ec2-user"
        done
    else
        print_msg "Docker doesn't exist on $1"
    fi
}

deploy_docker_plugin() {
 
     for ip in `cat ${DOCKERLAB} | grep -v \#`
     do
         if [ "${ip}" == "" ]; then
             continue
         fi

         pub_ip=`echo $ip | awk -F\| '{print $1}'`

         print_msg "Install docker plugin to ${pub_ip}"
         execute_remote_cmd "${pub_ip}" " git clone https://github.com/splunk/docker-logging-plugin.git; cd docker-logging-plugin; git checkout develop; make"
         execute_remote_cmd "${ip}" "docker plugin enable splunk-log-plugin"

     done
}

check_docker_plugin() {
    for ip in `cat ${DOCKERLAB} | grep -v \# | awk -F\| '{print $1}'`
    do
        if [ "${ip}" == "" ]; then
            continue
        fi

        print_msg "Check Docker status on ${ip}"


        docker_status=`execute_remote_cmd "${ip}" "sudo service docker status"`
        plugin_status=`execute_remote_cmd "${ip}" "docker plugin ls"`

        #print_msg "${docker_status} on node ${ip}"

        if grep -q running <<<$docker_status; then

            print_msg "Check Splunk log plugin on ${ip}"

            if grep -q splunk-log-plugin <<<$plugin_status; then
                print_msg "Splunk plugin found on node ${ip}"
            else
                print_msg "Splunk plugin not found on node ${ip}"
            fi

        else
            print_msg "Docker is not running on node ${ip}"
        fi



    done
}

start_server() {
    # $1 is the tag
    # $2 is the cmd
    # $3 is the ip

    if [[ "$3" == "" ]]; then
        for ip in `cat ${DOCKERLAB} | grep -v \# | awk -F\| '{print $1}'`
        do
            if [ "${ip}" == "" ]; then
                continue
            fi

            print_msg "Start $1 on ${ip}"
            ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=quiet -i ${CREDFILE} $USERNAME@${ip} "$2"

        done
    else
        print_msg "Start $1 on $3"
        execute_remote_cmd "${3}" "$2"
    fi
}



start_docker_plugin() {

    #Enable and run docker plugin
    start_server "docker" "sudo service docker start" "$1"
    #Start proc_monitor for resource monitoring
    #start_server "proc_monitor" "screen -S proc_monitor -m -d python /home/ec2-user/proc_monitor/proc_monitor.py &" "$1"
}

stop_docker_plugin() {
    if [[ "$1" == "" ]]; then
        for ip in `cat ${DOCKERLAB} | grep -v \# | awk -F\| '{print $1}'`
        do
            if [ "${ip}" == "" ]; then
                continue
            fi

            print_msg "Stop docker on ${ip}"
            #execute_remote_cmd "${ip}" "ps ax | grep -i 'docker' | grep -v grep | awk '{print \$1}' | xargs kill -9 > /dev/null 2>&1"
            execute_remote_cmd "${ip}" "sudo service docker stop > /dev/null 2>&1"
            print_msg "Stop proc_monitor on ${ip}"
            execute_remote_cmd "${ip}" "ps ax | grep -i 'monitor' | grep -v grep | xargs kill -9 > /dev/null 2>&1"
        done
    else
        print_msg "Stop docker on $1"
        #execute_remote_cmd "$1" "ps ax | grep -i 'docker' | grep -v grep | awk '{print \$1}' | xargs kill -9 > /dev/null 2>&1"
        execute_remote_cmd "${ip}" "sudo service docker stop > /dev/null 2>&1"
        print_msg "Stop proc_monitor on $1"
        execute_remote_cmd "$1" "ps ax | grep -i 'monitor' | grep -v grep | awk '{print \$1}' | xargs kill -9 > /dev/null 2>&1"

    fi
}

restart_docker_plugin() {
    stop_docker_plugin
    start_docker_plugin

}


clean_docker() {

    if [[ "$1" == "" ]]; then
        for ip in `cat ${DOCKERLAB} | grep -v \# | awk -F\| '{print $1}'`
        do
            if [ "${ip}" == "" ]; then
                continue
            fi

            stop_docker_plugin
            print_msg "Cleaning docker on ${ip}"
            execute_remote_cmd "${ip}" "sudo yum remove docker docker-common docker-selinux docker-engine -y; sudo rm -rf /var/lib/docker; sudo rm -rf /etc/docker; sudo rm -rf /var/log/docker; rm -rf docker-logging-plugin"
        done
    else
        print_msg "Docker doesn't exist on $1"
    fi


}


usage() {
cat << EOF
Usage: $0 options

    OPTIONS:
    --help    Show this message
    --install # install docker
    --deploy  # Deploy plugin
    --start 
    --stop
    --restart
    --clean
    --check
    --run #Start datagen container
EOF
exit 1
}

for arg in "$@"; do
    shift
    case "$arg" in
        "--help")
            set -- "$@" "-h"
            ;;
        "--start")
            set -- "$@" "-s"
            ;;
        "--restart")
            set -- "$@" "-r"
            ;;
        "--stop")
            set -- "$@" "-p"
            ;;
        "--deploy")
            set -- "$@" "-d"
            ;;
        "--check")
            set -- "$@" "-c"
            ;;
        "--start-compose")
            set -- "$@" "-l"
            ;;
        "--run")
            set -- "$@" "-o"
            ;;
        "--describe-topic")
            set -- "$@" "-i"
            ;;
        "--clean")
           set -- "$@" "-t"
           ;;
        "--install")
            set -- "$@" "-n"
            ;; 
        *)
            set -- "$@" "$arg"
    esac
done

cmd=
ips=
topic=

while getopts "hsropdlntci:" OPTION
do
    case $OPTION in
        h)
            usage
            ;;
        n)
            cmd="install"
            ;;
        d)
            cmd="deploy"
            ;;
        s)
            cmd="start"
            ;;
        p)
            cmd="stop"
            ;;
        r)
            cmd="restart"
            ;;
#        l)
#           cmd="start-compose"
#            ;;
        o)
            cmd="run"
            ;;
        i)
            cmd="describe_plugin"
            topic="$OPTARG"
            ;;
        t)
            cmd="clean"
            ;;
        c)
            cmd="check"
            ;; 
        *)
            usage
            ;;
    esac
done


read_user_cred

if [ "${USERNAME}" == "" ] || [ "${CREDFILE}" == ""  ]; then
    print_msg "Credentials are not found in ${CRED} file"
    exit 1
fi

if [[ "$cmd" == "install" ]]; then
    install_docker
elif [[ "$cmd" == "deploy" ]]; then
    deploy_docker_plugin
elif [[ "$cmd" == "start" ]]; then
    start_docker_plugin
elif [[ "$cmd" == "stop" ]]; then
    stop_docker_plugin
elif [[ "$cmd" == "restart" ]]; then
    restart_docker_plugin
elif [[ "$cmd" == "check" ]]; then
    check_docker_plugin
elif [[ "$cmd" == "clean" ]]; then
    clean_docker
elif [[ "$cmd" == "run" ]]; then
    run_container
else
    usage
fi
