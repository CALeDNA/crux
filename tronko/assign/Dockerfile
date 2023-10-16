FROM ubuntu:focal

ARG DEBIAN_FRONTEND=noninteractive

WORKDIR /mnt

RUN apt-get update && apt-get upgrade -yy && apt-get install -yy build-essential software-properties-common awscli \ 
    curl wget git libssl-dev libcurl4-openssl-dev libxml2-dev r-base-core pandoc -y && \
    wget -P /tmp/ "https://repo.anaconda.com/miniconda/Miniconda3-py38_4.12.0-Linux-x86_64.sh" && \
    bash "/tmp/Miniconda3-py38_4.12.0-Linux-x86_64.sh" -b -p /usr/local/miniconda

# Install cutadapt using pip from Miniconda
RUN /usr/local/miniconda/bin/python3 -m pip install --upgrade cutadapt

RUN wget https://www.poirrier.ca/ben/ben-2.16.tar.gz && \
    tar -xf ben-2.16.tar.gz && \
    mkdir -p /usr/local/bin && \
    cd ben && make && mv ben /usr/local/bin/ben

COPY env.yml /app/env.yml
COPY install_deps.R /app/install_deps.R

ENV PATH="/usr/local/bin:$PATH"
ENV PATH="/usr/local/miniconda/bin:$PATH"
ENV PATH="/usr/local/miniconda/envs/py27/bin:$PATH"

RUN git clone -b cruxv2 https://github.com/CALeDNA/Anacapa.git && \
conda create -n py27 python=2.7 && \
conda env update -f /app/env.yml -n py27 && \
conda init

RUN /app/install_deps.R