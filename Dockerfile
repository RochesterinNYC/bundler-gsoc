############################################################
# Dockerfile for Bundler GSoC
# Based on debian:jessie 
############################################################

FROM debian:jessie 
MAINTAINER James Wen (RochesterinNYC)

# Environment Setup
ENV LANG="C.UTF-8"
RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# Download Debian Packages
RUN apt-get update && apt-get install -y \
  patch bzip2 gawk g++ gcc make libc6-dev patch libreadline6-dev \
  zlib1g-dev libssl-dev libyaml-dev libsqlite3-dev sqlite3 autoconf \
  libgmp-dev libgdbm-dev libncurses5-dev automake libtool bison \
  pkg-config libffi-dev 
RUN apt-get install -y gnupg2 curl 
RUN apt-get install -y git-core
RUN apt-get install -y groff-base bsdmainutils

# Create and use bundler-dev user
RUN useradd --create-home --shell /bin/bash --user-group bundler-dev
USER bundler-dev

# Setup RVM
RUN gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
RUN curl -sSL https://get.rvm.io | bash -s stable
RUN source /home/bundler-dev/.rvm/scripts/rvm

# Install Ruby
RUN /bin/bash -l -c "rvm install 2.3.1"

# Update Rubygems and existing gems to proper version
RUN /bin/bash -l -c "gem update --system 2.6.4"
RUN /bin/bash -l -c "gem update"

# Install bundler spec dependencies
RUN git clone git://github.com/bundler/bundler.git $HOME/bundler-master
RUN cd $HOME/bundler-master && /bin/bash -l -c "bin/rake spec:deps"
