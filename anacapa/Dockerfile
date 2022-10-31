FROM nghoffman/dada2:release-1.6.0

WORKDIR /app

RUN apt-get update &&  \ 
    apt-get install apt-transport-https parallel jq \ 
    curl wget git -y
RUN wget -P /tmp/ "https://repo.anaconda.com/miniconda/Miniconda3-py37_4.12.0-Linux-x86_64.sh" && \
    bash "/tmp/Miniconda3-py37_4.12.0-Linux-x86_64.sh" -b -p /usr/local/miniconda

ENV PATH="/usr/local/miniconda/bin:$PATH"

RUN conda install -c bioconda cutadapt fastx_toolkit
RUN conda init && \
    . /root/.bashrc

COPY install-deps.R /app/install-deps.R
RUN Rscript --vanilla install-deps.R
