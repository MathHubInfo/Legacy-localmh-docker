# README

## What is this?

This repository contains a [Docker](https://www.docker.com/) Image for [localmh](https://github.com/KWARC/localmh) and a wrapper to (almost) semmlessly use localmh on another system. Currently the wrapper script only supports Linux and MacOSX.

## Installation

The installation consists of 2 parts, installing docker and installing the wrapper script.

### Requirements

The wrapper script depends only on bash, git and docker 1.7+. If you want to use the localmh_docker script properly you will need some knowledge on how to set up environment variables, how to make them permanent and what your $PATH is.

### Docker requirements
* You need docker 1.7+ or the script will not work.
* You need to be able to run docker without the use of sudo, as the script will not work as root.

### Installing docker

When installing docker, please install version 1.4 or newer. Instructions on how to install docker are not covered here, but they can be found in [the offical Docker Installation Guide](https://docs.docker.com/installation/). On Mac OS X it is neccessary to Docker Manager (or a similar script) to manage docker. If you are using that script, please have the docker-machine vm name ready during th installation of lmh.

### Installing the localmh_docker script

1. ```git clone``` this repository to an arbitrary path on your system
2. Symlink ```lmh.sh``` into a folder that is in your PATH, for example: ```sudo ln -s lmh.sh  /usr/local/bin/lmh```
3. You can install localmh in two ways:
  1. You want to develop the content managed by lmh only. In this case it is sufficient to make the ```MathHub``` directory available on the local system. For this purpose you should create a folder somewhere on your real machine and set the environment variable ```LMH_DATA_DIR``` to point to it.
  2. You want to develop lmh or any of the dependent software itself. In this case you should ```git clone``` the [KWARC/localmh](https://github.com/KWARC/localmh) repository to a folder of your choice and point to it using the ```LMH_ROOT_DIR``` variable.
4. If you are using Docker-machine manager on Mac OS X, you should set the ```LMH_DOCKER_MACHINE``` environment variable to the name of the VM you are using. Note that the default machine name is ```default```.

## Update

If you have installed lmh as above you can update by running:

```bash
git pull # wherever you cloned this repository to
lmh docker pull # pull the new localmh_docker image
lmh docker stop; lmh docker delete # stop and delete the container
lmh docker create # re-create it.
```

```git pull``` in the path where you originally cloned this repository. Next you should run lmh core pullimag

## Managing the lmh docker container

### Show container status

Use the ```lmh docker status``` command to see the current status of the container.

### Creating & Deleting the container

Use the ```lmh docker create``` command to create a new container for the docker image. This can only be done if a container does not yet exist. Every time the docker image is updated you will need to create a new container. You will also have to create a new container if you want to change the mounted directories or the user account.

You can delete a container using the ```lmh docker delete``` command. To delete a container it needs to be stopped first. Deleting a container can not be undone.

### Starting & Stopping the container

You can start and stop a container using the commands ```lmh docker start``` and ```lmh docker stop``` respectively. When you start a container, the SSH keys inside the container will need to be re-registered, so if your SSH keys are protected with a password you might have to re-enter it.

### Working with the container
You can directly use all ```lmh *``` commands without having to go into the docker container manually. They are run as a limited user inside the container. To use a command inside the docker container the container needs to be running.

If you need a shell inside the docker container, you can use the command ```lmh docker shell``` to get a user-level shell. If you need root access use ```lmh docker sshell``` instead.

### Working with the kwarc/localmh docker Image
For convenience, ```localmh_docker``` provides the ```lmh docker build``` and ```lmh docker pull``` commands to re-build and pull the image. Please see the ```lmh docker --help``` command for more information.

## License

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
