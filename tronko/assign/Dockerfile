FROM ubuntu:focal

ARG DEBIAN_FRONTEND=noninteractive

WORKDIR /mnt

RUN apt-get update && apt-get upgrade -yy && apt-get install -yy build-essential software-properties-common awscli \ 
    curl wget git libssl-dev libcurl4-openssl-dev libxml2-dev r-base-core -y && \
    wget -P /tmp/ "https://repo.anaconda.com/miniconda/Miniconda3-py38_4.12.0-Linux-x86_64.sh" && \
    bash "/tmp/Miniconda3-py38_4.12.0-Linux-x86_64.sh" -b -p /usr/local/miniconda

COPY env.yml /app/env.yml
COPY install_deps.R /app/install_deps.R

ENV PATH="/usr/local/miniconda/bin:$PATH"
ENV PATH="/usr/local/miniconda/envs/py27/bin:$PATH"

RUN git clone -b cruxv2 https://github.com/CALeDNA/Anacapa.git && \
conda create -n py27 python=2.7 && \
conda env update -f /app/env.yml -n py27 && \
conda init

RUN /app/install_deps.R