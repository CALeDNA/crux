FROM ubuntu:focal

ARG DEBIAN_FRONTEND=noninteractive

WORKDIR /app

RUN apt-get update && apt-get upgrade -yy && apt-get install -yy build-essential software-properties-common \ 
    apt-transport-https npm cmake parallel python3-openstackclient jq awscli \ 
    curl wget git libssl-dev libcurl4-openssl-dev libxml2-dev -y && \
    npm i nugget -g && \
    wget -P /tmp/ "https://repo.anaconda.com/miniconda/Miniconda3-py38_4.12.0-Linux-x86_64.sh" && \
    bash "/tmp/Miniconda3-py38_4.12.0-Linux-x86_64.sh" -b -p /usr/local/miniconda

COPY env.yml /app/env.yml
ADD crux/bin /usr/local/crux_bin

RUN mkdir -p /root/.ssh && \
    chmod 0700 /root/.ssh

COPY config /root/.ssh/config
COPY hbaez-private-key /root/.ssh/hbaez-private-key
RUN chmod 600 /root/.ssh/*

ENV PATH="/usr/local/crux_bin:$PATH"
ENV PATH="/usr/local/miniconda/bin:$PATH"

RUN conda install -n base -c anaconda cython && \
    conda env update -f /app/env.yml -n base && \
    conda init && \
    . /root/.bashrc
