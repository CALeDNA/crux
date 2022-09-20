FROM ubuntu:focal

ARG DEBIAN_FRONTEND=noninteractive

WORKDIR /app

RUN apt-get update && apt-get upgrade -yy && apt-get install -yy build-essential software-properties-common \ 
    apt-transport-https npm cmake parallel ncbi-blast+ \ 
    curl wget git libssl-dev libcurl4-openssl-dev libxml2-dev -y && \
    npm i nugget -g && \
    wget -P /tmp/ "https://repo.anaconda.com/miniconda/Miniconda3-py38_4.12.0-Linux-x86_64.sh" && \
    bash "/tmp/Miniconda3-py38_4.12.0-Linux-x86_64.sh" -b -p /usr/local/miniconda
    # echo "export PATH=/usr/local/miniconda/bin:$PATH" >> /usr/local/.bashrc

# ADD app /app
COPY app/env.yml /app/env.yml
ADD bin /usr/local/crux_bin

# RUN echo "export PATH=/usr/local/crux_bin:$PATH" >> /usr/local/.bashrc
ENV PATH="/usr/local/crux_bin:$PATH"
ENV PATH="/usr/local/miniconda/bin:$PATH"

RUN conda install -n base -c anaconda cython && \
    conda env update -f /app/env.yml -n base && \
    conda init && \
    . /root/.bashrc
