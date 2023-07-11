FROM ubuntu:focal

ARG DEBIAN_FRONTEND=noninteractive

WORKDIR /app

RUN apt-get update && apt-get upgrade -yy && apt-get install -yy build-essential software-properties-common \ 
    apt-transport-https libz-dev npm cmake parallel python3-openstackclient jq awscli unzip \ 
    curl wget git libssl-dev libcurl4-openssl-dev libxml2-dev -y && \
    npm i nugget -g && \
    wget -P /tmp/ "https://repo.anaconda.com/miniconda/Miniconda3-py38_4.12.0-Linux-x86_64.sh" && \
    bash "/tmp/Miniconda3-py38_4.12.0-Linux-x86_64.sh" -b -p /usr/local/miniconda

COPY env.yml /app/env.yml
ADD bin /usr/local/crux_bin

RUN git clone https://github.com/stamatak/standard-RAxML.git && \
    cd standard-RAxML && make -f Makefile.gcc && make -f Makefile.AVX2.gcc && \
    make -f Makefile.AVX2.PTHREADS.gcc && make -f Makefile.PTHREADS.gcc && \
    make -f Makefile.SSE3.PTHREADS.gcc && make -f Makefile.SSE3.gcc && \
    mv raxmlHPC* /usr/local/crux_bin

RUN git clone https://github.com/lpipes/AncestralClust.git && \
    cd AncestralClust && make && mv ancestralclust /usr/local/crux_bin

RUN git clone https://github.com/lpipes/tronko.git && \
    cd tronko/tronko-build && make && mv tronko-build /usr/local/crux_bin && \
    cd ../tronko-assign && make && mv tronko-assign /usr/local/crux_bin

ENV PATH="/usr/local/crux_bin:$PATH"
ENV PATH="/usr/local/miniconda/bin:$PATH"

RUN conda install -n base -c anaconda cython && \
    conda env update -f /app/env.yml -n base && \
    conda init && \
    . /root/.bashrc
