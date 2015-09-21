# README

## What is this?

This repository contains a [Docker](https://www.docker.com/) Image for [localmh](https://github.com/KWARC/localmh) and a wrapper to (almost) semmlessly use localmh on another system. Currently the wrapper script only supports Linux and MacOSX.

## Installation

The installation consists of 2 parts, installing docker and installing the wrapper script.

### Requirements

The wrapper script depends only on bash, git and docker. If you want to use the localmh_docker script properly you will need some knowledge on how to set up environment variables, how to make them permanent and what your $PATH is.

### Installing docker

When installing docker, please install version 1.4 or newer. Instructions on how to install docker are not covered here, but they can be found in [the offical Docker Installation Guide](https://docs.docker.com/installation/). On Mac OS X it is neccessary to Docker Manager (or a similar script) to manage docker. If you are using that script, please have the docker-machine vm name ready during th installation of lmh.

### Installing the localmh_docker script

1) ```git clone``` this repository to an arbitrary path on your system
2) Symlink ```lmh.sh``` into a folder that is in your PATH, for example: ```sudo ln -s lmh.sh  /usr/local/bin/lmh```
3) You can install localmh in two ways:
  3a) You want to develop the content managed by lmh only. In this case it is sufficient to make the ```MathHub``` directory available on the local system. For this purpose you should create a folder somewhere on your real machine and set the environment variable ```LMH_DATA_DIR``` to point to it.
  3b) You want to develop lmh or any of the dependent software itself. In this case you should ```git clone``` the [KWARC/localmh](https://github.com/KWARC/localmh) repository to a folder of your choice and point to it using the ```LMH_ROOT_DIR``` variable.
4) If you are using Docker-machine manager on Mac OS X, you should set the ```LMH_DOCKER_MACHINE``` environment variable to the name of the VM you are using. Note that the default machine name is ```default```.

## Update

If you have installed lmh as above you can update by running:

```bash
git pull # whereever you installed this repository
lmh docker pull # pull the localmh_docker image
lmh docker delete # delete the localmh_docker container
lmh docker create # create the localmh_docker container
```

```git pull``` in the path where you originally cloned this repository. Next you should run lmh core pullimag

## Managing the lmh docker container



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
