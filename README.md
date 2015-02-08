# README

## What is this?

This repository contains a [Docker](https://www.docker.com/) Image for [localmh](https://github.com/KWARC/localmh) and a wrapper to (almost) semmlessly use localmh on another system. Currently the wrapper script only supports Linux and MacOSX.

## Installation

The installation consists of 2 parts, installing docker and installing the wrapper script.

### Requirements

The wrapper script depends only on bash and docker. To install it however, you will need some knowledge on how to set up environment variables, how to make them permanent and what your $PATH is.

### Installing docker

When installing docker, please install version 1.4 or newer. This guide will take you through the process of installing docker / boot2docker on Linux and MacOSX. This is only a short guide. For full instructions (specific for your system) please refer to [the offical Docker Installation Guide](https://docs.docker.com/installation/).

#### Linux

To install Docker, run the following line from a terminal:
```bash
curl -sSL https://get.docker.com/ | sh
```
or if you do not have curl installed, run instead:
```bash
wget -qO- https://get.docker.com/ | sh
```

This will ask for your administrator password when required. At the end of the setup script it will provide instructions on how to run docker without the use of sudo. It is recommended to follow those. Afterwards you will have to logout and login again before the changes take effect.

#### MacOSX

Because docker needs some kernel-specific features, to run docker on MacOSX you will also need boot2docker, a light-weight VM optimised for running docker. Please refer to [this page](https://docs.docker.com/installation/mac/) for more information. you can follow the instructions on how to install docker there.

Whenever running the wrapper script, please make sure that the boot2docker VM is running.

### Installing the wrapper script

First, download and store the wrapper script in a location that is contained in your $PATH. (Note: it is recommended to remove any legacy lmh installation first via ```[sudo] pip uninstall lmh```. )
```bash
cd /in/your/path/
wget -O lmh https://raw.githubusercontent.com/KWARC/localmh_docker/master/lmh.sh
chmod +x lmh # Make the script executable
```
or
```bash
cd /in/your/path/
curl https://raw.githubusercontent.com/KWARC/localmh_docker/master/lmh.sh > lmh
chmod +x lmh # Make the script executable
```
Feel free to use other methods to get the wrapper script. For example, you can just clone this repository and then symlink the executable. This will make updates significantly simpler.

Then you should create a directory for your Data files which will be available inside the docker container:
```bash
mkdir MathHub
export LMH_CONTENT_DIR="/path/to/MathHub"
```
and make the environment variable LMH_CONTENT_DIR permanent. You are now ready to use the wrapper script (see Usage below.)

If you ever want to change the path to this directory, please make sure to stop all running lmh processes and then destroy the docker container that contains lmh:
```bash
lmh core destroy
```
Afterwards you can change the directory in any way you want.

### Updating the wrapper script

To update the wrapper script, simply replace the script you installed earlier with the newest version from this repository. In the future this project will be automated this process.

## Using the wrapper script

Before using the wrapper script, you will need to understand how it works. It creates a docker container which has lmh installed for you. This container is isolated from the host system and only has access to the LMH_CONTENT_DIR (as configured above). This has a few caveats, see below.

### Caveats

Because everything is running inside a docker container, all configuration from outside the container is not maintained. If you want to use git (which is essential to the way lmh works), you will have to reconfigure the git inside the container. Each time you destroy the container you will have to repeat this procedure. You can do this via calling:
```
lmh core start
```
to open a regular shell inside the container. Then you can use normal git commands to configure git properly.

To copy over .ssh keys inside the container, please use:

```
lmh core cpssh /real/path/to/id_rsa /real/path/to/id_rsa.pub
```
On most configurations this is simply:
```
lmh core cpssh $HOME/.ssh/id_rsa $HOME/.ssh/id_rsa.pub
```

If this fails, you can also do this manually:
```
# Make sure you have created $HOME/.ssh inside the container
lmh core put /real/path/to/id_rsa /root/.ssh/id_rsa
lmh core put /real/path/to/id_rsa.pub /root/.ssh/id_rsa.pub
```
which will copy over ssh keys to the docker container. Then do:

```
lmh core start # Opens a shell inside the container
# Sets ssh permissions correctly
chmod 600 ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa.pub
exit # exists the shell created by lmh core
```
### Regular usage

If the wrapper script is named "lmh" you can use the normal lmh commands seemlessly. The only exception from this is "lmh core" which is handled by the wrapper script only. The commands will be run inside the docker container, however it has proper access to the LMH_DATA_DIR and will automatically run commands in the right directory. If no container exists or it is not running, it will automatically be created.

For more information on the supported core commands, please run
```
lmh core --help
```

You can create the docker container via running:
```
lmh core start
```
This creates the container (if it does not already exists) and creates a shell inside of it.
You can stop the running container via:
```
lmh core stop
```

To destroy a container (usually not needed), use ```lmh core destroy````. Furthermore you can use
```
lmh core status
```
for some status information.


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
