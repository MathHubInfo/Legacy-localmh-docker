# Docker container for lmh
# (c) The KWARC Group 2015

FROM debian:stable

MAINTAINER Tom Wiesing <tkw01536@gmail.com>

ENV TERM xterm

#
# STEP 1: INSTALL APT-GET PACKAGES
#
RUN echo "Installing apt-get packages" && \

    # Pull package lists and upgrade existing packages.
    apt-get update && \
    apt-get dist-upgrade -y && \

    # Install all the required dependencies
    apt-get install -y wget perl python3 python3-dev python3-pip git tar fontconfig cpanminus libxml2-dev libxslt-dev libssl-dev libgdbm-dev liblwp-protocol-https-perl openjdk-7-jre-headless bindfs && \

    # Clear apt-get caches to save space
    apt-get clean && rm -rf /var/lib/apt/lists/*


#
# STEP 2: Install TexLive + Fonts
#

ADD files/install.profile /root/texlive/install.profile

RUN echo "Installing TexLive 2015" && \

    # Create the texlive directory
    mkdir -p /root/texlive/ && \

    # Grab the setup image
    wget -nv -O /root/texlive/texlive.tar.gz http://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz && \

    # Untar it to /root/texlive
    tar -xzf /root/texlive/texlive.tar.gz -C /root/texlive --strip-components=1 && \

    # Run the installer
    cd /root/texlive && ./install-tl --profile install.profile && \

    # Remove /root/textlive and /tmp
    rm -rf /root/texlive && \
    rm -rf /tmp/*

# Set TexLive paths
ENV INFOPATH /usr/local/texlive/2015/texmf-dist/doc/info:$INFOPATH
ENV INFOPATH /usr/local/texlive/2015/texmf-dist/doc/man:$MANPATH
ENV PATH /usr/local/texlive/2015/bin/x86_64-linux:$PATH

# Add the profile and fonts (for KWARC/localmh#217)
ADD files/FandolFang-Regular.otf /usr/share/fonts/opentype/Fandol/
ADD files/cwTeXQKai-Medium.ttf /usr/share/fonts/truetype/cwTeX/

RUN echo "Updating TexLive Settings and fonts" && \

    # Re-generate font cache
    fc-cache && \

    # set special sTeX parameters
    echo "max_in_open = 50\nparam_size = 20000\nnest_size = 1000\nstack_size = 10000\n" >> $(kpsewhich texmf.cnf)


#
# STEP 3: Make some directories
#

RUN echo "Creating directories ..." && \
    mkdir -p /path/to/home && chmod a+rw /path/to/home/ && \
    mkdir -p /path/to/home/.ssh && chmod a+rw /path/to/home/.ssh && \
    mkdir -p /path/to/localmh/ && chmod a+rw /path/to/localmh/

#
# STEP 4: Pull lmh and install.
#

ADD files/lmh /usr/local/bin/lmh

RUN echo "Installing lmh" && \

    # Clone it from github
    git clone https://github.com/KWARC/localmh /path/to/localmh && \

    # Install pip dependencies (without cache)
    pip3 install beautifulsoup4 psutil pyapi-gitlab && \

    # Remove the python cache
    rm -rf /root/.pip/cache/ && \

    # Make the MathHub directory
    mkdir -p /path/to/localmh/MathHub && \

    # Run the setup process
    lmh setup --install all

# STEP 4: FINAL SETUP
#

ADD files/localmh_init /sbin/localmh_init
ADD files/sshag.sh /path/to/home/sshag.sh

CMD ["/sbin/localmh_init"]
