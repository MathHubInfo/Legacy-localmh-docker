#!/bin/bash

lmh_repo="tkw01536/localmh"
lmh_configfile="$HOME/.lmh_docker"
lmh_mountdir="$(pwd)"

# Executables needed
docker=$(which docker)

# Check if docker exists.
if [ "$docker" != "" ]; then
  :
else
  echo "Docker not found. "
  exit 1
fi
if [ -x $docker ]; then
  :
else
  echo "Docker not found. "
  exit 1
fi

#
# Check if we have a config file
#
if [ -r "$lmh_configfile" ]; then
  docker_pid=$(cat $lmh_configfile)
else
  docker_pid=""
fi

if [ "$1" == "help" ]; then
  echo """LMH Wrapper Script

Usage: $0 [start|status|stop|destroy|help]

  start   Connects to a container for lmh. Default.
  status  Checks the status of the container.
  stop    Stops the container for lmh.
  destroy Destroys the local lmh container.
  help    Displays this help message.
"""
  exit 0
fi

#
# For the stop command, exit the container.
#
if [ "$1" == "stop" ]; then
  docker stop -t 1 $docker_pid
  exit $?
fi

#
# For the status command, show the status
#

if [ "$1" == "status" ]; then
  if [ "$docker_pid" == "" ]; then
    echo "Container Id: <none>"
  else
    echo "Container Id: $docker_pid"
    if [ "$(docker inspect --format='{{ .State.Running }}' $docker_pid)" == "false" ]; then
      echo "Status:       Not running"
    else
      echo "Status:       Running"
    fi
  fi
  exit 0
fi

#
# Unknown command
#
if [ "$1" != "start" ]; then
  if [  "$1" != "" ]; then
    echo "Unknown command. "
    exit 1
  fi
fi

#
# Create container if it does not exist.
#
if [ "$(docker inspect --format='{{ .State.Running }}' $docker_pid 2> /dev/null || echo 'no')" == "no" ]; then
  echo "Creating new container for lmh ..."
  docker_pid=$(docker create $lmh_repo)
  echo $docker_pid > "$lmh_configfile"
fi

#
# Start the container if it isn't already.
#
if [ "$(docker inspect --format='{{ .State.Running }}' $docker_pid)" == "false" ]; then
  docker start $docker_pid
fi

# and connect to it.
docker exec -t -i $docker_pid /bin/bash
exit $?
