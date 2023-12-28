FROM debian:bookworm

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get -y update && apt-get -y upgrade

RUN apt-get install -y locales && \
    sed -i 's/^# *\(en_US.UTF-8.*\)/\1/' /etc/locale.gen && \
    locale-gen

RUN apt-get -y install apt-utils adduser debian-goodies util-linux \
    build-essential perl-doc libipc-run-perl libarchive-zip-perl \
    wamerican libbsd-dev ruby python3 pkg-config time curl\
    clang-tools valgrind openjdk-17-jdk python-is-python3 \
    unzip build-essential autoconf m4 libncurses5-dev libssh-dev \
    xsltproc fop libxml2-utils libncurses-dev libxml-parser-perl

RUN apt-get -y install git wget

RUN adduser inkfish --disabled-password --gecos "Inkfish Build,,,,"

COPY --chown=inkfish:inkfish use-asdf.sh /home/inkfish

RUN su - inkfish -c 'bash ~/use-asdf.sh'
