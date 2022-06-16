FROM ubuntu:xenial

WORKDIR /app

# install apt dependencies
RUN apt-get update && apt-get upgrade -yy && \
	apt-get install -yy build-essential software-properties-common apt-transport-https curl wget git libssl-dev libcurl4-openssl-dev libxml2-dev && \
	wget -P /tmp/ "https://repo.continuum.io/miniconda/Miniconda2-4.7.12-Linux-x86_64.sh" && \
	bash "/tmp/Miniconda2-4.7.12-Linux-x86_64.sh" -b -p /usr/local/miniconda && \
	echo "export PATH=/usr/local/miniconda/bin:\$PATH" >> /usr/local/.bashrc


COPY crux.yml /app/crux.yml


# create conda env and install dependecies
RUN cd /usr/local && \
	. /usr/local/.bashrc && \
	conda env create -f /app/crux.yml
