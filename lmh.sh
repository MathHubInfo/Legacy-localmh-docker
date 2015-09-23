#!/bin/bash

# make sure we are running bash
if ! [ -n "$BASH_VERSION" ]; then
    echo "You need to use bash for this. ";
    exit 1;
fi

#
# (c) 2015 the KWARC group <kwarc.info>
#

# Self
lmh_wrap_version="1.0.0"

# Core
lmh_docker_repo="kwarc/localmh" # Docker repository for lmh.
lmh_container_name="localmh_docker" # Name of lmh docker container
lmh_machine_name="hostname" # Hostname of the machine
lmh_user_name="user" # Name of the user
lmh_group_name="group" # Name of the group for the user
lmh_host_name="hostname" # Host name of the docker machine.

# find the path of lmh
pushd `dirname $(realpath $0)` > /dev/null
lmh_script_path=`pwd`
popd > /dev/null


# Intialise a variable including a default.
function init_var()
{
  if [ -z "${!1}" ];
  then   echo $2;
  else   echo "${!1}";
  fi
}

function cleanup_directory()
{
  echo "$1" | $sed -e 's/\/*$//g'
}

# Code to autostart docker-machine VM
# Unused on Linux.
function docker_machine_support
{
  # Run docker machine code if we support it.
  if [ -z "$LMH_DOCKER_MACHINE" ]; then : ; else

    docker_machine_status="$($docker_machine status $LMH_DOCKER_MACHINE 2> /dev/null)"

    # If docker machine is not started, we want to start it.
    if [ "$docker_machine_status" == "Stopped" ] && [ "$1" != "off" ]; then
      $docker_machine start $LMH_DOCKER_MACHINE > /dev/null
    fi

    # get the environment variables (if applicable)
    if [ "$1" != "off" ]; then
      eval "$($docker_machine env $LMH_DOCKER_MACHINE 2> /dev/null)";
    fi

  fi;
}


function docker_container_running
{
  [ "$($docker inspect --format="{{ .State.Running }}" $lmh_container_name 2> /dev/null)" == "true" ]
  return $?
}

function docker_container_exists
{
  if $docker inspect --format="{{ .State.Running }}" $lmh_container_name &> /dev/null; then
    return 0;
  else
    return 1;
  fi;
}

function docker_ensure_running
{

  # Start the docker machine if available.
  docker_machine_support

  if docker_container_running; then
    return 0;
  fi;

  if docker_container_exists; then
    >&2 echo "Docker container does not exist, please create one using lmh docker init. "
    exit 1;
  fi;

  >&2 echo "Docker container is not running, please start it using lmh docker start. "
  exit 1;

}

function lmh_docker_status
{
  # Make sure docker_machine is running
  docker_machine_support

  # Is the container running?
  if docker_container_running; then
    lmh_docker_status="true";
  else
    lmh_docker_status="false";
  fi;

  # Does the container exist?
  if docker_container_exists; then
    lmh_docker_existence="true"
  else
    lmh_docker_existence="false"
  fi;


  echo "ENVIRONMENT:"
  echo ""
  echo "LMH_DATA_DIR        = " "$LMH_DATA_DIR"
  echo "LMH_ROOT_DIR        = " "$LMH_ROOT_DIR"
  echo "LMH_DOCKER_MACHINE  = " "$LMH_DOCKER_MACHINE"
  echo "LMH_SSH_DIR         = " "$LMH_SSH_DIR"
  echo ""
  echo ""
  echo "DOCKER CONTAINER:"
  echo ""
  echo "Name:             " $lmh_container_name
  echo "Container exists: " $lmh_docker_existence
  echo "Container active: " $lmh_docker_status
  echo ""

}


#
# LMH_DOCKER_CREATE
#
function lmh_docker_create
{
  # Make sure we have a docker machine.
  docker_machine_support

  # if the docker container already exists, exit.
  if docker_container_exists; then
    >&2 echo "Docker container exists already. Can not create another one. "
    exit 1;
  fi;

  printf "Creating and starting docker container ... "



  # Step 1: Create a docker container and run nothing in it.

  if [ "$lmh_mode" == "content" ]; then
    docker_localmh_mount="$LMH_DATA_DIR:/mounted/lmh/MathHub"
  else
    docker_localmh_mount="$LMH_ROOT_DIR:/mounted/lmh"
  fi;

  $docker run --privileged=true -d --name $lmh_container_name -h $lmh_host_name -v "$docker_localmh_mount" -v "$LMH_SSH_DIR:/mounted/ssh" $lmh_docker_repo &> /dev/null

  # If we did not create it, then exit.
  if [ $? -ne 0 ]; then
    echo "Failed. "
    >&2 echo "Unable to create docker container ... "
    exit $?;
  fi;

  echo "Done. "

  printf "Creating user and group inside docker container ... "

  # Step 2: Create an appropriate user.
  $docker exec $lmh_container_name /bin/bash -c "chown $user_id:$group_id /path/to/home; groupadd -g $group_id $lmh_group_name 2> /dev/null; groupmod -n $lmh_group_name \$(getent group 20 | cut -d: -f1) ; useradd -d /path/to/home -p $lmh_user_name -u $user_id -g $group_id user; " &> /dev/null

  # If we did not create it, then exit.
  if [ $? -ne 0 ]; then
    echo "Failed. "
    >&2 echo "Warning: Unable to create user and group. ";
  else
    echo "Done. "
  fi;

  # Step 3: Set up git.
  printf "Configuring git settings ... "

  gitcfgs=( "user.name" "user.email")

  for i in "${gitcfgs[@]}"
  do
    git_cfg="$(git config --get $i)"

    $docker exec -u $uid:$gid  $lmh_container_name /bin/bash -c "cd \$HOME && git config --system $i \"$git_cfg\"" &> /dev/null
  done

  echo "Done. "

  # and stop the container again.
  lmh_docker_stop
}

function lmh_docker_start
{
  # Make sure docker_machine is running.
  docker_machine_support

  # If it does not exist there is nothing to stop.
  if docker_container_exists; then
    :
  else
    >&2 echo "Docker container does not exist, there is nothing to start. "
    exit 1;
  fi;

  # Container is running, can not stop.
  if docker_container_running; then
    >&2 echo "Docker container is already running, can not start it. "
    exit 1;
  else

    printf "Starting docker container ... "

    $docker start $lmh_container_name &> /dev/null

    if [ $? -ne 0 ]; then
      echo "Failed. "
      exit 1;
    fi;

    bindfs_commandline="-u $lmh_user_name -g $lmh_group_name"


    echo "Done. "
    printf "Remounting directories with correct permissions, please wait ... "
    $docker exec $lmh_container_name /bin/bash -c "umount /path/to/home/.ssh; bindfs --perms=u+r $bindfs_commandline /mounted/ssh /path/to/home/.ssh" &> /dev/null

    if [ "$lmh_mode" == "content" ]; then
      $docker exec $lmh_container_name /bin/bash -c "umount /path/to/localmh/MathHub; bindfs -o nonempty --perms=a+rw $bindfs_commandline /mounted/lmh/MathHub /path/to/localmh/MathHub"  &> /dev/null;
      $docker exec
    else
      $docker exec $lmh_container_name /bin/bash -c "umount /path/to/localmh; bindfs -o nonempty --perms=a+rw $bindfs_commandline /mounted/lmh /path/to/localmh"  &> /dev/null;
    fi;

    echo "Done. "
    printf "Linking directories ... "

    if [ "$lmh_mode" == "content" ]; then
      $docker exec $lmh_container_name /bin/bash -c "mkdir -p $(dirname $LMH_DATA_DIR); rm -f $LMH_DATA_DIR; ln -s /path/to/localmh/MathHub $LMH_DATA_DIR";
    else
      $docker exec $lmh_container_name /bin/bash -c "mkdir -p $(dirname $LMH_ROOT_DIR); rm -f $LMH_ROOT_DIR; ln -s /path/to/localmh $LMH_ROOT_DIR";
    fi;
    echo "Done. "

    echo "Registering ssh keys, you might have to enter your password. "

    # Run the ssh magic.
    $docker exec -u $user_id:$group_id -t -i $lmh_container_name /bin/bash -c "export HOME=/path/to/home; source /path/to/home/sshag.sh; ssh-add; echo \"The following ssh keys are available: \"; ssh-add -l; "

    # and we are done.
    echo "Done. "

    exit 0;
  fi;
}

function lmh_docker_stop
{
  # Make sure docker_machine is running.
  docker_machine_support

  # If it does not exist there is nothing to stop.
  if docker_container_exists; then
    :
  else
    >&2 echo "Docker container does not exist, there is nothing to stop. "
    exit 1;
  fi;

  # Container is running, can not stop.
  if docker_container_running; then
    printf "Unmounting directories ... "
    $docker exec -t -i  $lmh_container_name /bin/bash -c 'umount /path/to/localmh; umount /path/to/localmh/MathHub; umount /path/to/home/.ssh; ' &> /dev/null

    echo "Done. "

    printf "Stopping docker container ... "
    $docker stop $lmh_container_name &> /dev/null

    if [ $? -ne 0 ]; then
      echo "Failed. "
    else
      echo "Done. "
    fi;

    exit $?;
  else
    >&2 echo "Docker container is not running, so it can not be stopped. "
    exit 1;
  fi;
}

function lmh_docker_delete
{
  # Make sure docker_machine is running.
  docker_machine_support

  # If it does not exist there is nothing to delete.
  if docker_container_exists; then
    :
  else
    >&2 echo "Docker container does not exist, there is nothing to delete. "
    exit 1;
  fi;

  # Container is running, can not delete.
  if docker_container_running; then
    >&2 echo "Docker container is running. Can not delete a running container. "
    exit 1;
  fi;

  printf "Deleting docker container ... "
  $docker rm $lmh_container_name &> /dev/null

  if [ $? -ne 0 ]; then
    echo "Failed. "
    exit 1;
  else
    echo "Done. "
    exit 0;
  fi;
}


#
# LMH_DOCKER_PULL
#
function lmh_docker_pull
{
  # Make sure docker_machine is running
  docker_machine_support

  # Pull the image
  $docker pull $lmh_docker_repo

  # exit with whatever code that gave.
  exit $?
}

#
# LMH_DOCKER_PULL
#
function lmh_docker_build
{
  # Make sure docker_machine is running
  docker_machine_support

  # cd into the lmh script path.
  cd $lmh_script_path

  # build the image.
  $docker build -t $lmh_docker_repo .

  # exit with whatever code that gave.
  exit $?
}

#
# LMH_DOCKER_SHELL
#
function lmh_docker_shell
{
  # Make sure docker_machine is running
  docker_machine_support

  if docker_container_exists; then
    :
  else
    >&2 echo "Docker container does not exist, can not start a shell. "
    exit 1;
  fi;

  if docker_container_running; then
    :
  else
    >&2 echo "Docker container is not running, can not start a shell. "
    exit 1;
  fi;

  $docker exec -u $user_id:$group_id -t -i $lmh_container_name /bin/bash -c "export HOME=/path/to/home; export TERM=xterm; source /path/to/home/sshag.sh; cd $lmh_pwd; /bin/bash"
}

#
# LMH_DOCKER_SSHELL
#
function lmh_docker_sshell
{
  # Make sure docker_machine is running
  docker_machine_support

  if docker_container_exists; then
    :
  else
    >&2 echo "Docker container does not exist, can not start a shell. "
    exit 1;
  fi;

  if docker_container_running; then
    :
  else
    >&2 echo "Docker container is not running, can not start a shell. "
    exit 1;
  fi;

  $docker exec -t -i $lmh_container_name /bin/bash -c "export TERM=xterm; cd $lmh_pwd; /bin/bash"
}

#
# LMH_DOCKER_HELP
#

docker_usage="Usage: $0 docker [help|--help] [create|start|stop|status|delete|pull|build] [ARGS]"
function lmh_docker_help()
{
  echo """lmh_docker wrapper script, version $lmh_wrap_version

(c) 2015 The KWARC group <kwarc.info>

$docker_usage

  Managing the $lmh_container_name docker container:

  create  Creates a new $lmh_container_name container.
  start   Starts the existing $lmh_container_name container.
  stop    Stops the existing $lmh_container_name container.
  status  Checks the status of the $lmh_container_name container.
  delete  Deletes the existing $lmh_container_name container.

  Accessing the $lmh_container_name:

  shell   Creates a (limited user) shell inside the $lmh_container_name container.
  sshell  Creates a root shell inside the $lmh_container_name container.

  Managing the $lmh_docker_repo docker image:

  pull    Pulls a new $lmh_docker_repo image from dockerhub.
  build   Builds the $lmh_docker_repo image locally.

  help    Displays this help message.
  --help  Alias for $0 core help


Environment Variables:
  LMH_DATA_DIR
          A data directory to be mounted inside the docker container.
  LMH_ROOT_DIR
          localmh installation to be mounted inside the docker container. If
          this variable is set it overrides LMH_DATA_DIR.
  LMH_DOCKER_MACHINE
          Name of the docker-machine VM to be used, if applicable.
          localmh_docker will autostart this docker machine if needed.
  LMH_SSH_DIR
          Path to SSH directory of keys to use inside lmh. Defaults to
          \$HOME/.ssh


License:
  localmh_docker is licensed under GPL 3. The full license text can be found in
  $lmh_script_path/gpl-3.0.txt.
"""
  exit 0
}



#
# MAIN COMMANDS
#
function lmh_docker()
{
  # lmh docker create
  if [ "$2" == "create" ]; then
    lmh_docker_create
    return
  fi;

  # lmh docker start
  if [ "$2" == "start" ]; then
    lmh_docker_start
    return
  fi;

  # lmh docker stop
  if [ "$2" == "stop" ]; then
    lmh_docker_stop
    return
  fi;

  # lmh docker delete
  if [ "$2" == "delete" ]; then
    lmh_docker_delete
    return
  fi;

  # lmh docker status
  if [ "$2" == "status" ]; then
    lmh_docker_status
    return
  fi;

  # lmh docker pull
  if [ "$2" == "pull" ]; then
    lmh_docker_pull
    return
  fi;

  # lmh docker build
  if [ "$2" == "build" ]; then
    lmh_docker_build
    return
  fi;

  # lmh docker shell
  if [ "$2" == "shell" ]; then
    lmh_docker_shell
    return
  fi;

  # lmh docker sshell
  if [ "$2" == "sshell" ]; then
    lmh_docker_sshell
    return
  fi;

  # lmh docker [help|--help]
  if [ "$2" == "help" ] || [ "$2" == "--help" ]; then
    lmh_docker_help
    return
  fi;

  # everything else
  >&2 echo "Unknown command '$2'"
  >&2 echo $docker_usage
  exit 1
}

function lmh_()
{
  # Make sure docker_machine is running
  docker_machine_support

  if docker_container_exists; then
    :
  else
    >&2 echo "Docker container does not exist, please create it using 'lmh docker create'. "
    exit 1;
  fi;

  if docker_container_running; then
    :
  else
    >&2 echo "Docker container is not running, please start it using 'lmh docker start'. "
    exit 1;
  fi;

  lmh_line="$@"

  $docker exec -u $user_id:$group_id -t -i $lmh_container_name /bin/bash -c "export HOME=/path/to/home; export TERM=xterm; source /path/to/home/sshag.sh; cd $lmh_pwd;/usr/local/bin/lmh $lmh_line"

  exit $?


}

# Paths to executables
docker="$(which docker 2> /dev/null)"
docker_machine="$(which docker-machine 2> /dev/null)"
sed="$(which sed 2> /dev/null)"

# Defaults which can be changed by the user.
LMH_DATA_DIR="$(init_var "LMH_DATA_DIR" "$HOME/MathHub")"
LMH_ROOT_DIR="$(init_var "LMH_ROOT_DIR" "")"
LMH_DOCKER_MACHINE="$(init_var "LMH_DOCKER_MACHINE" "")"
LMH_SSH_DIR="$(init_var "LMH_SSH_DIR" "$HOME/.ssh")"

# check if LMH_DATA_DIRECTORY exists.
if [ -z "$LMH_DATA_DIR" ]; then
  :
else
  if [ -d "$LMH_DATA_DIR" ]; then
    LMH_DATA_DIR=$(cleanup_directory "$LMH_DATA_DIR")
    lmh_mode="content";
  else
    if [ -z "$LMH_ROOT_DIR" ]; then
      >&2 echo "LMH_DATA_DIR variable set non-existent directory $LMH_DATA_DIR"
      exit 1
    fi;
  fi;
fi;

# check for devecdlopment directory
if [ -z "$LMH_ROOT_DIR" ]; then
  :
else
  if [ -d "$LMH_ROOT_DIR" ]; then
    LMH_ROOT_DIR=$(cleanup_directory "$LMH_ROOT_DIR")
    lmh_mode="dev";
  else
    >&2 echo "LMH_ROOT_DIR variable set non-existent directory $LMH_ROOT_DIR"
    exit 1
  fi;
fi;

# check for development directory
if [ -z "$LMH_SSH_DIR" ]; then
  :
else
  if [ -d "$LMH_SSH_DIR" ]; then
    LMH_SSH_DIR=$(cleanup_directory "$LMH_SSH_DIR")
  else
    >&2 echo "LMH_SSH_DIR variable set non-existent directory $LMH_SSH_DIR"
    exit 1
  fi;
fi;

# If we have no mode, exit
if [ -z "$lmh_mode" ]; then
  >&2 echo "Neither LMH_DATA_DIR nor LMH_ROOT_DIR are set, exiting. "
  exit 1
fi

# Set current relative directory paths.
lmh_pwd="$(pwd)"

# for content mode, we go relative to the LMH_DATA_DIR
if [ "$lmh_mode" == "content" ]; then
  if [[ $lmh_pwd/ != $LMH_DATA_DIR/* ]]; then
    lmh_pwd="$LMH_DATA_DIR";
  fi;
# else we go relative to the root directory of lmh.
else
  if [[ $lmh_pwd/ != $LMH_ROOT_DIR/* ]]; then
    lmh_pwd="$LMH_ROOT_DIR";
  fi;
fi;

# Grab user and group id.
user_id="$(id -u)"
group_id="$(id -g)"

if [ "$1" == "core" ] || [ "$1" == "docker" ]; then
  lmh_docker "$@";
else
  lmh_ "$@";
fi;
