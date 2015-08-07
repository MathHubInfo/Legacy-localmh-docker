# Docker container for lmh
# (c) The KWARC Group 2015

FROM debian:stable

MAINTAINER Tom Wiesing <tkw01536@gmail.com>

#
# Install TexLive vanilla
#

#make sure HOME points to root even if this changes later on.
ENV HOME /root

# make apt-get faster, from https://gist.github.com/jpetazzo/6127116
# this forces dpkg not to call sync() after package extraction and speeds up install
RUN echo "force-unsafe-io" > /etc/dpkg/dpkg.cfg.d/02apt-speedup
# we don't need and apt cache in a container
RUN echo "Acquire::http {No-Cache=True;};" > /etc/apt/apt.conf.d/no-cache

#
# Install needed packages
# This might take a while
#

RUN apt-get update && \
    apt-get dist-upgrade -y && \
    apt-get install -y wget perl && \
    apt-get clean

# make directory and add the installation profile
RUN mkdir -p $HOME/texlive
ADD files/install.profile $HOME/texlive/install.profile

# download the installer,
# run it and then
# remove the installer again (we do not need it anymore)
RUN wget -nv -O $HOME/texlive/texlive.tar.gz http://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz; \
    tar -xzf $HOME/texlive/texlive.tar.gz -C $HOME/texlive --strip-components=1; \
    rm $HOME/texlive/texlive.tar.gz; \
    cd $HOME/texlive && ./install-tl --persistent-downloads --profile install.profile; \
    rm -rf $HOME/texlive

# Add the TEXLIVE PATHs
ENV INFOPATH /usr/local/texlive/2015/texmf-dist/doc/info:$INFOPATH
ENV INFOPATH /usr/local/texlive/2015/texmf-dist/doc/man:$MANPATH
ENV PATH /usr/local/texlive/2015/bin/x86_64-linux:$PATH

#
# Install all the packages
# This might take a while
#

RUN apt-get install -y python python-dev python-pip git tar fontconfig cpanminus libxml2-dev libxslt-dev libssl-dev libgdbm-dev liblwp-protocol-https-perl openjdk-7-jre-headless && \
    apt-get clean

#
# Install lmh itself
#
RUN git clone https://github.com/KWARC/localmh /path/to/localmh; \
    pip install beautifulsoup4 psutil pyapi-gitlab; \
    ln -s /path/to/localmh/bin/lmh /usr/local/bin/lmh; \
    lmh setup --install all

# Install fonts
# see KWARC/localmh#217
RUN mkdir -p /usr/share/fonts/opentype/Fandol && \
    mkdir -p /usr/share/fonts/truetype/cwTeX
ADD files/FandolFang-Regular.otf /usr/share/fonts/opentype/Fandol/
ADD files/cwTeXQKai-Medium.ttf /usr/share/fonts/truetype/cwTeX/

RUN fc-cache

# We need to change a few variables for sTeX to work.
RUN echo "max_in_open = 50\nparam_size = 20000\nnest_size = 1000\nstack_size = 10000\n" >> $(kpsewhich texmf.cnf)

# Set up some ssh agent magic.
ADD files/sshag.sh $HOME/sshag.sh

#
# AND run nothing.
#
CMD /bin/bash -c "source ~/sshag.sh; tail -f /dev/null"
