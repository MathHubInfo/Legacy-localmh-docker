#!/bin/bash

#
# (c) 2015 the KWARC group <kwarc.info>
#

#=================================
# CONFIG
#=================================

# Docker repository for lmh.
lmh_repo="kwarc/localmh"

# Configuration file to store the container in.
lmh_configfile="$HOME/.lmh_docker"

# Directory to mount if the directory is not directly given.
lmh_mountdir="$HOME/MathHub"

# Directory to SSH files.
lmh_sshdir="$HOME/.ssh"

# Paths to executables
docker="$(which docker)"
sed="$(which sed)"

#=================================
# HELPERS
#=================================

function need_executable()
{
  # Checks if a function exists
  # @param $0 - path of executable to check.
  # @param $1 - Name of executable to print.

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

#=================================
# CORE COMMANDS
#=================================

function command_help()
{
  # Provides help text

  echo """LMH Docker Wrapper Core Script

(c) 2015 The KWARC group <kwarc.info>

Usage: $0 core [start|status|stop|destroy|sshinit|put|get|fp|help] [--help] [ARGS]

  start   Connects to a container for lmh. Creates a new container if it does
          not already exist.
  status  Checks the status of the container.
  stop    Stops the container for lmh.
  destroy Destroys the local lmh container.
  sshinit Updates ssh keys inside the container.
  put     Copy files from the host system to the docker container.
  get     Copy files from the docker container to the host system.
  fp      Fix permissions of the mounted directries.
  help    Displays this help message.
  --help  Alias for $0 core help

Environment Variables:
  LMH_CONTENT_DIR Directory to mount as MathHub data directory inside the
                  container.
  LMH_DEV_DIR     Directory to mount as localmh installation inside the
                  container. Overwrites the above and should only be needed for
                  developers.

  Changes to these variables requires the created to be destroyed and re-created
  via:
    lmh core destroy
    lmh core start

When a new container is created the MathHub directory in the lmh instance will
have to be mounted. By default, this script mounts the current directory. This
behaviour can be overriden by setting the LMH_CONTENT_DIR environment variable
to an existing directory.

Example:
  LMH_CONTENT_DIR="\$HOME/localmh/MathHub" $0 start
    If no container exists, creates a new one with the directory
    \$HOME/localmh/MathHub used as a directory for data files. If a container
    already exists, attaches to it.
=======
Environment Variables:
  LMH_CONTENT_DIR Directory to mount as MathHub data directory inside the
                  container.
  LMH_DEV_DIR     Directory to mount as localmh installation inside the
                  container. Overwrites the above and should only be needed for
                  developers.

  Changes to these variables requires the created to be destroyed and re-created
  via:
    lmh core destroy
    lmh core start

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

Usage: $0 core [start|cp|status|stop|destroy|sshinit|put|get|fp|help] [--help] [ARGS]

See $0 core --help for more information. """ >&2
  exit 1
}

function command_ensure_exists(){
  if [ -z "$docker_pid" ]; then
    echo "Nothing to do since the container does not exist..."
    exit 0
  fi
}

function command_ensure_running(){
  # make sure everything is set up properly

  # Create container if it does not exist.
  if [ "$(docker inspect --format='{{ .State.Running }}' $docker_pid 2> /dev/null || echo 'no')" == "no" ]; then
    echo "Creating docker container. "

    # Mount directories inside the container.
    # We have the data directory and the .ssh directory.

    if [ "$lmh_devmode" == "true" ]; then
      docker_pid=$(docker create -t -v "$lmh_sshdir:/root/.ssh" -v "$lmh_devdir:/path/to/localmh"  $lmh_repo )
    else
      docker_pid=$(docker create -t -v "$lmh_sshdir:/root/.ssh" -v "$lmh_mountdir:/path/to/localmh/MathHub" $lmh_repo )
    fi

    # Store the pid inside the configfile.
    # TODO: Firgure out how to name stuff.
    echo $docker_pid > "$lmh_configfile"
  fi

  # Start the container if it isn't already.
  if [ "$(docker inspect --format='{{ .State.Running }}' $docker_pid)" == "false" ]; then
    $docker start $docker_pid > /dev/null

    # Now just link inside the container correctly.
    if [ "$lmh_devmode" == "true" ]; then
      $docker exec -t -i $docker_pid /bin/bash -c 'cd $HOME; if [[ -L '"$lmh_mountdir"' ]]; then : ; else echo "Linking LMH_DEV_DIR ..." && mkdir -p '"$lmh_devdir"' && rmdir '"$lmh_devdir"' && ln -s /path/to/localmh '"$lmh_devdir"'; fi '
    else
      $docker exec -t -i $docker_pid /bin/bash -c 'cd $HOME; if [[ -L '"$lmh_mountdir"' ]]; then : ; else echo "Linking LMH_CONTENT_DIR ..." && mkdir -p '"$lmh_mountdir"' && rmdir '"$lmh_mountdir"' && ln -s /path/to/localmh/MathHub '"$lmh_mountdir"'; fi '
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

  echo "Currently in:   $lmh_pwd"
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

  cat "${1}" | $docker exec -i $docker_pid /bin/sh -c "cat > \"${2}\""
  exit 0
}

function command_get(){
  # Get files from inside the container

  command_ensure_exists

  if [ "${1}" == "" ] || [ "${2}" == "" ]; then
    echo """Usage: $0 core get CONTAINERFILE HOSTFILE
Copies a file CONTAINERFILE inside the
container to the file HOSTFILE on the host system. Overwrites existing files.
"""
    exit 0
  fi

  command_ensure_running

  $docker exec -t -i $docker_pid /bin/sh -c "cat \"${1}\"" > "${2}"
  exit 0
}

function command_start(){
  # Starts the lmh container.

  command_ensure_running

  $docker exec -t -i $docker_pid /bin/bash -c "cd $lmh_pwd; source \$HOME/sshag.sh; /bin/bash"
  exit $?
}

function command_stop(){

  command_ensure_exists

  # Stops the docker container.
  $docker stop -t 1 $docker_pid
  exit $?
}

function run_wrapper_lmh(){
  # Run the lmh inside

  # Check that the command is running.
  command_ensure_running

  lmhline="lmh $@"

  $docker exec -t -i $docker_pid /bin/bash -c "source \$HOME/sshag.sh; cd $lmh_pwd; $lmhline"
  exit $?
}

function command_fp(){
  # fix permissions in the mounted directory.

  command_ensure_running

  # get id and uid
  uid="$(id -u)"
  gid="$(id -g)"

  # run the command.
  $docker exec $docker_pid  /bin/sh -c "chown -R $uid:$gid /path/to/localmh"
  exit $?
}

function command_sshinit(){
  # fix permissions in the mounted directory.

  command_ensure_running

  # run the command.
  $docker exec $docker_pid  /bin/bash -c "source \$HOME/sshag.sh; ssh-add; echo \"=======\"; ssh-add -l"
  exit $?
}

function command_destroy(){
  command_ensure_exists

  # Destroys the lmh container
  $docker rm -f $docker_pid
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

  if [ "${1}" == "sshinit" ]; then
    command_sshinit
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

  if [ "${1}" == "fp" ]; then
    command_fp
    exit 0
  fi

  command_unknown "${1}"
  exit 1
}

#=================================
# Initalisation code
#=================================

# check if dependencies exist.
need_executable "$docker" "Docker"
need_executable "$sed" "sed"

# Check if we want to mount a different directory.
if [ -d "$LMH_CONTENT_DIR" ]; then
  # Remove trailing slashes
  LMH_CONTENT_DIR=$(echo "$LMH_CONTENT_DIR" | $sed -e 's/\/*$//g')
  lmh_mountdir="$LMH_CONTENT_DIR"
fi

# For dev mode, we want to mount the dev dir.
if [ -d "$LMH_DEV_DIR" ]; then
  # Remove trailing slashes
  LMH_DEV_DIR=$(echo "$LMH_DEV_DIR" | $sed -e 's/\/*$//g')

  lmh_devmode="true"
  lmh_devdir="$LMH_DEV_DIR"
  lmh_mountdir="$LMH_DEV_DIR/MathHub"
fi

# If we are not in dev mode
# and the directory is not given
# give a warning and die
if [ "$lmh_devmode" != "true" ]; then
  if [ ! -d "$lmh_mountdir" ]; then
    echo "Mount directory $lmh_mountdir does not exist, exiting. "
    exit 1
  fi
fi

# Check if we have a config file, if so read in the id of the docker container.
if [ -r "$lmh_configfile" ]; then
  docker_pid=$(cat $lmh_configfile)
else
  docker_pid=""
fi

# Check if we are inside the mounted directory.
lmh_pwd="$(pwd)"
lmh_pwdcut="$(echo "$lmh_pwd" | cut -c 1-$((${#lmh_mountdir})))"

#If not, we just cd into the mounted directory
if [[ "$lmh_mountdir" != "$lmh_pwdcut" ]]; then
  lmh_pwd="$lmh_mountdir"
fi

#
if [ "$1" == "core" ]; then
  command_core "$2" "$3" "$4"
  exit $?
else
  run_wrapper_lmh "$@"
  exit $?
fi
