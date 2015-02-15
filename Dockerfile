# Docker container for lmh
# (c) The KWARC Group 2015

FROM debian:stable

MAINTAINER Tom Wiesing <tkw01536@gmail.com>

# make apt-get faster, from https://gist.github.com/jpetazzo/6127116
# this forces dpkg not to call sync() after package extraction and speeds up install
RUN echo "force-unsafe-io" > /etc/dpkg/dpkg.cfg.d/02apt-speedup
# we don't need and apt cache in a container
RUN echo "Acquire::http {No-Cache=True;};" > /etc/apt/apt.conf.d/no-cache

#
# Install all the packages
# This might take a while
#

RUN apt-get update && \
    apt-get dist-upgrade -y && \
    apt-get install -y python python-dev python-pip git subversion wget tar fontconfig perl cpanminus libxml2-dev libxslt-dev libgdbm-dev openjdk-7-jre-headless && \
    apt-get clean
#
# Install TexLive vanilla
#

#make sure HOME points to root even if this changes later on.
ENV HOME /root

# make directory and add the installation profile
RUN mkdir -p $HOME/texlive
ADD install.profile $HOME/texlive/install.profile
# download the installer,
# run it and then
# remove the installer again (we do not need it anymore)
RUN wget -nv -O $HOME/texlive/texlive.tar.gz http://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz; \
    tar -xzf $HOME/texlive/texlive.tar.gz -C $HOME/texlive --strip-components=1; \
    rm $HOME/texlive/texlive.tar.gz; \
    cd $HOME/texlive && ./install-tl --persistent-downloads --profile install.profile; \
    rm -rf $HOME/texlive

# Add the TEXLIVE PATHs
ENV INFOPATH /usr/local/texlive/2014/texmf-dist/doc/info:$INFOPATH
ENV INFOPATH /usr/local/texlive/2014/texmf-dist/doc/man:$MANPATH
ENV PATH /usr/local/texlive/2014/bin/x86_64-linux:$PATH

#
# Install lmh itself
#
RUN git clone https://github.com/KWARC/localmh $HOME/localmh; \
    pip install beautifulsoup4 psutil pyapi-gitlab; \
    ln -s $HOME/localmh/bin/lmh /usr/local/bin/lmh; \
    lmh setup --no-firstrun --install all

#
# And run the tail command, to do nothing
#
CMD tail -f /dev/null
