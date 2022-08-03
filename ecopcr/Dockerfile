FROM ubuntu:focal

ARG DEBIAN_FRONTEND=noninteractive

WORKDIR /app

RUN apt-get update && apt-get upgrade -yy && apt-get install -yy build-essential software-properties-common apt-transport-https \ 
	curl wget git libssl-dev libcurl4-openssl-dev libxml2-dev s3fs awscli parallel -y && \
	wget -P /tmp/ "https://repo.anaconda.com/miniconda/Miniconda3-py38_4.12.0-Linux-x86_64.sh" && \
	bash "/tmp/Miniconda3-py38_4.12.0-Linux-x86_64.sh" -b -p /usr/local/miniconda && \
	echo "export PATH=/usr/local/miniconda/bin:\$PATH" >> /usr/local/.bashrc

ADD ecopcr /app/

RUN cd /usr/local && \
	. /usr/local/.bashrc && \
	conda env create -f /app/environment.yml && \
	conda init && \
	. /root/.bashrc
