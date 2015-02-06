# README

This branch contains the docker image and wrapper script for lmh.

## Install Docker

(1) Install docker. Make sure you have version 1.4 or higher. You can do this by running

```bash
curl -sSL https://get.docker.com/ | sh
```

or

```bash
wget -qO- https://get.docker.com/ | sh
```

(2) Make sure you can run docker without using "sudo". You might have to add yourself to the group "docker".

## Install lmh

(1) Download the script in this repository and put it somewhere in your $PATH. You can do this via:

```bash
wget -O lmhwrap https://raw.githubusercontent.com/KWARC/localmh/docker/lmhwrap.sh
chmod +x lmhwrap # Make the script executable
```

or

```bash
curl https://raw.githubusercontent.com/KWARC/localmh/docker/lmhwrap.sh > lmhwrap
chmod +x lmhwrap # Make the script executable
```
(2) Create a directory for your Data files which will be available inside the docker container:

```bash
mkdir MathHub; cd MathHub
export LMH_CONTENT_DIR="/path/to/MathHub"
```

(3) Make this environment variable permanent (important) by putting it in your .bash_rc or .bash_profile .

## Using lmh

(4) You can now run the script whenever you want to open a shell inside the docker container.

```bash
lmhwrap start
```
