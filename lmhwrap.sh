#!/bin/bash

lmh_repo="tkw01536/localmh"
lmh_configfile="$HOME/.lmh_docker"
lmh_mountdir="$(pwd)"

if [ -d "$LMH_CONTENT_DIR" ]; then
  lmh_mountdir="$LMH_CONTENT_DIR"
fi

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

(c) 2015 The KWARC group <kwarc.info>

Usage: $0 [start|status|stop|destroy|help]

  start   Connects to a container for lmh. Creates a new container if it does
          not already exist. Default.
  status  Checks the status of the container.
  stop    Stops the container for lmh.
  destroy Destroys the local lmh container.
  help    Displays this help message.

When a new container is created the MathHub directory in the lmh instance will
have to be mounted. By default, this script mounts the current directory. This
behaviour can be overriden by setting the LMH_CONTENT_DIR environment variable
to an existing directory.

Example:
  LMH_CONTENT_DIR="\$HOME/localmh/MathHub" $0 start
    If no container exists, creates a new one with the directory
    \$HOME/localmh/MathHub used as a directory for data files. If a container
    already exists, attaches to it.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
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
# Computing the relative directories.
#
lmh_pwd="$(pwd)"
lmh_pwdcut="$(echo "$lmh_pwd" | cut -c 1-$((${#lmh_mountdir})))"
lmh_relpath=$(pwd | cut -c $((${#lmh_mountdir} + 2))-)

if [[ "$lmh_mountdir" != "$lmh_pwdcut" ]]; then
  lmh_relpath=""
else
  lmh_relpath="MathHub/$lmh_relpath"
fi



#
# For the destroy command remove the container
#
if [ "$1" == "destroy" ]; then
  docker rm -f $docker_pid
  exit $?
fi

#
# For the status command, show the status
#

if [ "$1" == "status" ]; then
  if [ "$docker_pid" == "" ]; then
    echo "Container Id:   <none>"
  else
    echo "Container Id:   $docker_pid"
    if [ "$(docker inspect --format='{{ .State.Running }}' $docker_pid)" == "false" ]; then
      echo "Status:         Not running"
    else
      echo "Status:         Running"
    fi
  fi
  echo "Data directory: $lmh_mountdir"
  exit 0
fi

#
# Unknown command
#
if [ "$1" != "start" ]; then
  if [ "$1" != "" ]; then
    echo "Unknown command. "
    exit 1
  fi
fi


#
# Create container if it does not exist.
#
if [ "$(docker inspect --format='{{ .State.Running }}' $docker_pid 2> /dev/null || echo 'no')" == "no" ]; then
  echo "Creating new container for lmh ..."
  docker_pid=$(docker create -v "$lmh_mountdir:/lmh_content_dir" $lmh_repo )
  echo $docker_pid > "$lmh_configfile"
fi

#
# Start the container if it isn't already.
#
if [ "$(docker inspect --format='{{ .State.Running }}' $docker_pid)" == "false" ]; then
  docker start $docker_pid

  # Link the MathHub directory if we have to.
  docker exec -t -i $docker_pid /bin/bash -c 'cd $HOME/localmh; if [[ -L MathHub ]]; then : ; else echo "Linking MathHub directory ..." && mv MathHub $HOME/MathHub.org && ln -s /lmh_content_dir MathHub ; fi '
fi


docker exec -t -i $docker_pid /bin/sh -c "cd \$HOME/localmh/$lmh_relpath; /bin/bash"
exit $?
