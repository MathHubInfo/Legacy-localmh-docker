#!/bin/bash

#
# (c) 2015 the KWARC group <kwarc.info>
#


#
# CONFIGURATION
#
lmh_repo="kwarc/localmh" # docker repository for lmh
lmh_configfile="$HOME/.lmh_docker" # file to store state in.
lmh_mountdir="$(pwd)" # Default directory to mount.


#
# END CONFIGURATION
#


#
# UTILITY FUNCTIONS
#

function need_executable()
{
  # checks if a function exists
  if [ "${1}" != "" ]; then
    :
  else
    echo "${2} not found. "
    exit 1
  fi
  if [ -x ${1} ]; then
    :
  else
    echo "${2} not found. "
    exit 1
  fi
}

#
# COMMAND FUNCTIONS
#

function command_help()
{
  echo """LMH Core Script

(c) 2015 The KWARC group <kwarc.info>

Usage: $0 core [start|status|stop|destroy|put|get|fp|help] [--help] [ARGS]

  start   Connects to a container for lmh. Creates a new container if it does
          not already exist.
  status  Checks the status of the container.
  stop    Stops the container for lmh.
  destroy Destroys the local lmh container.
  put     Copy files from the host system to the docker container.
  get     Copy files from the docker container to the host system.
  cpssh   Copy over the ssh keys from the host system.
  fp      Fix permissions of the mounted directries.
  help    Displays this help message.
  --help  Alias for $0 core help

When a new container is created the MathHub directory in the lmh instance will
have to be mounted. By default, this script mounts the current directory. This
behaviour can be overriden by setting the LMH_CONTENT_DIR environment variable
to an existing directory.

Example:
  LMH_CONTENT_DIR="\$HOME/localmh/MathHub" $0 start
    If no container exists, creates a new one with the directory
    \$HOME/localmh/MathHub used as a directory for data files. If a container
    already exists, attaches to it.

Licensing information:
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
}

function command_unknown(){
  echo """$0 core: Unknown command ${1}

Usage: $0 core [start|cp|status|stop|destroy|put|get|cpssh|fp|help] [--help] [ARGS]

See $0 core --help for more information. """ >&2
  exit 1
}

function command_ensure_running(){
  # make sure everything is set up properly

  # Create container if it does not exist.
  if [ "$(docker inspect --format='{{ .State.Running }}' $docker_pid 2> /dev/null || echo 'no')" == "no" ]; then
    echo "Creating new container. "
    if [ "$lmh_devmode" == "true" ]; then
      docker_pid=$(docker create -t -e SSH_AUTH_SOCK=/ssh-agent -v $(dirname $SSH_AUTH_SOCK):/ssh-agent -v "$lmh_devdir:/path/to/localmh"  $lmh_repo )
    else
      docker_pid=$(docker create -t -e SSH_AUTH_SOCK=/ssh-agent -v $(dirname $SSH_AUTH_SOCK):/ssh-agent -v "$lmh_mountdir:/path/to/localmh/MathHub" $lmh_repo )
    fi
    echo $docker_pid > "$lmh_configfile"
  fi

  # Start the container if it isn't already.
  if [ "$(docker inspect --format='{{ .State.Running }}' $docker_pid)" == "false" ]; then
    docker start $docker_pid > /dev/null

    if [ "$lmh_devmode" == "true" ]; then
      # Link the MathHub directory if we have to.
      docker exec -t -i $docker_pid /bin/bash -c 'cd $HOME; if [[ -L localmh ]]; then : ; else echo "Linking localmh directory in development mode. " && mv localmh localmh.org && ln -s /path/to/localmh localmh ; fi '
    else
      # Link the MathHub directory if we have to.
      docker exec -t -i $docker_pid /bin/bash -c 'cd $HOME/localmh; if [[ -L MathHub ]]; then : ; else echo "Linking localmh/MathHub directory mode. " && mv MathHub $HOME/MathHub.org && ln -s /path/to/localmh/MathHub MathHub ; fi '
    fi
  fi

}

function command_status(){
  # The status command.

  if [ "$docker_pid" != "" ] && [ "$(docker inspect --format='{{ .State.Running }}' $docker_pid 2> /dev/null || echo 'no')" == "no" ]; then
    docker_pid=""
    rm $lmh_config_file
  fi

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
  if [ "$lmh_devmode" == "true" ]; then
    echo "Dev directory: $lmh_devdir"
  else
    echo "Data directory: $lmh_mountdir"
  fi
  exit 0
}

function command_put(){
  # Put files inside

  if [ "${1}" == "" ] || [ "${2}" == "" ]; then
    echo """Usage: $0 core put HOSTFILE CONTAINERFILE
Copies a file # Install lmh itself
HOSTFILE from the host system to the file CONTAINERFILE inside the
container. Overwrite existing files.
"""
    exit 0
  fi

  command_ensure_running

  cat "${1}" | docker exec -i $docker_pid /bin/sh -c "cat > \"${2}\""
  exit 0
}

function command_get(){
  # Get files from inside the container

  if [ "${1}" == "" ] || [ "${2}" == "" ]; then
    echo """Usage: $0 core get CONTAINERFILE HOSTFILE
Copies a file CONTAINERFILE inside the
container to the file HOSTFILE on the host system. Overwrites existing files.
"""
    exit 0
  fi

  command_ensure_running

  docker exec -t -i $docker_pid /bin/sh -c "cat \"${1}\"" > "${2}"
  exit 0
}

function command_start(){
  # Starts the lmh container.

  command_ensure_running

  docker exec -t -i $docker_pid /bin/sh -c "cd \$HOME/localmh/$lmh_relpath; /bin/bash"
  exit $?
}

function command_stop(){
  # Stops the docker container.
  docker stop -t 1 $docker_pid
  exit $?
}

function run_wrapper_lmh(){
  # Run the lmh inside

  command_ensure_running

  out_path="$lmh_mountdir"
  if [ "$lmh_devmode" == "true" ]; then
    in_path="/path/to/localmh/MathHub"
  else
    in_path="/path/to/localmh"
  fi

  # Replace absolute paths
  # There might be problems with this, so we need to check this again.
  lmh_line=$(echo "lmh $@" | sed "s|^$out_path|$in_path|" | sed "s| $out_path| $in_path|")
  #echo $lmh_line

  docker exec -t -i $docker_pid /bin/sh -c "cd \$HOME/localmh/$lmh_relpath; $lmh_line"

  exit $?
}

function command_cpssh(){

  # copy over the ssh

  if [ "${1}" == "" ] && [ "${2}" == "" ]; then
    id_rsa_path="$HOME/.ssh/id_rsa"
    id_rsa_pub_path="$HOME/.ssh/id_rsa.pub"
  else
    if [ "${1}" == "" ] || [ "${2}" == "" ]; then
      echo """Usage: $0 core cpssh [ID_RSA ID_RSA_PUB]
Copies over the ssh keys from the host system to the container.
If no parameters are given, uses the standard location.
"""
      exit 0
    fi
    id_rsa_path="${1}"
    id_rsa_pub_path="${2}"
  fi

  command_ensure_running

  # Create $HOME/.ssh
  docker exec -t $docker_pid /bin/sh -c "mkdir -p \$HOME/.ssh"

  # Copy over the id_rsa and id_rsa.pub
  $0 core put "$id_rsa_path" /root/.ssh/id_rsa
  $0 core put "$id_rsa_pub_path" /root/.ssh/id_rsa.pub

  # Fix permissions
  docker exec $docker_pid  /bin/sh -c "chmod 600 \$HOME/.ssh/id_rsa"
  docker exec $docker_pid  /bin/sh -c "chmod 600 \$HOME/.ssh/id_rsa.pub"

  # The end.
  exit $?
}

function command_fp(){
  # fix permissions in the mounted directory.

  command_ensure_running

  # get id and uid
  uid="$(id -u)"
  gid="$(id -g)"

  # run the command.
  docker exec $docker_pid  /bin/sh -c "chown -R $uid:$gid /path/to/localmh"
  exit $?
}

function command_destroy(){
  # Destroys the lmh container
  docker rm -f $docker_pid
  rm $lmh_configfile
  exit $?
}

function command_core(){
  # Runs if we are in the core.

  if [ "${1}" == "help" ] || [ "${1}" == "--help" ]; then
    command_help
    exit 0
  fi

  if [ "${1}" == "status" ]; then
    command_status
    exit 0
  fi


  if [ "${1}" == "start" ]; then
    command_start
    exit 0
  fi

  if [ "${1}" == "stop" ]; then
    command_stop
    exit 0
  fi

  if [ "${1}" == "destroy" ]; then
    command_destroy
    exit 0
  fi

  if [ "${1}" == "put" ]; then
    command_put "${2}" "${3}"
    exit 0
  fi

  if [ "${1}" == "get" ]; then
    command_get "${2}" "${3}"
    exit 0
  fi

  if [ "${1}" == "cpssh" ]; then
    command_cpssh "${2}" "${3}"
    exit 0
  fi

  if [ "${1}" == "fp" ]; then
    command_fp
    exit 0
  fi

  command_unknown "${1}"
  exit 1
}

#
# MAIN CODE
#

# Check if we want to mount a different directory.
if [ -d "$LMH_CONTENT_DIR" ]; then
  lmh_mountdir="$LMH_CONTENT_DIR"
fi

# For when when we do deving.
if [ -d "$LMH_DEV_DIR" ]; then
  lmh_devmode="true"
  lmh_devdir="$LMH_DEV_DIR"
  lmh_mountdir="$LMH_DEV_DIR/MathHub"
fi

# Check if we have the docker excutable
docker=$(which docker)
need_executable "$docker" "Docker"

# Check if we have a config file, if so read in the id of the docker container.
if [ -r "$lmh_configfile" ]; then
  docker_pid=$(cat $lmh_configfile)
else
  docker_pid=""
fi

# Computing the relative directories.
lmh_pwd="$(pwd)"
lmh_pwdcut="$(echo "$lmh_pwd" | cut -c 1-$((${#lmh_mountdir})))"
lmh_relpath=$(pwd | cut -c $((${#lmh_mountdir} + 2))-)

# are we inside the mount_dir
if [[ "$lmh_mountdir" != "$lmh_pwdcut" ]]; then
  lmh_relpath=""
else
  lmh_relpath="MathHub/$lmh_relpath"
fi

#
if [ "$1" == "core" ]; then
  command_core "$2" "$3" "$4"
  exit $?
else
  run_wrapper_lmh "$@"
fi
