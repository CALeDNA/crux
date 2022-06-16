FROM ubuntu:xenial

ENV NSPAWN_BOOTSTRAP_IMAGE_SIZE=10GB

WORKDIR /app

# install apt + npm dependencies
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

RUN . /usr/local/.bashrc && \
    conda init bash --verbose


# RUN cd test/ && \
# 	tar xvzf crux_db.tar.gz && \
# 	cd crux_db/ && \
# 	chmod +x crux.sh


# # run crux and check for correct bison tax
# RUN . /root/.bashrc && \
# 	conda activate crux && \
# 	cd test/crux_db/ && \
# 	./crux.sh -n 16S -f CGAGAAGACCCTATGGAGCT -r CCGAGGTCRCCCCAACC -s 30 -m 200 -e 3 -o 16S -d ./ -l && \
# 	cd 16S/16S_db_unfiltered/16S_fasta_and_taxonomy && \
# 	if [ -s 16S_taxonomy.txt ]; then echo "unfiltered taxonomy not empty"; else echo "unfiltered taxonomy empty" && exit 1; fi
