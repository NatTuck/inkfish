FROM debian:bookworm

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get -y update && apt-get -y upgrade

RUN apt-get install -y locales && \
    sed -i 's/^# *(en_US.UTF-8)/1/' /etc/locale.gen && \
    locale-gen

RUN apt-get -y install apt-utils adduser

RUN apt-get -y install debian-goodies util-linux \
    build-essential perl-doc libipc-run-perl libarchive-zip-perl \
    wamerican libbsd-dev ruby python3 pkg-config time curl

RUN adduser student --disabled-password --gecos "Student,,,,"
