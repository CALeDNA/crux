#! /bin/bash
set -x
# setup script to get main vm ready

# setup conda
wget -P . "https://repo.anaconda.com/miniconda/Miniconda3-py38_4.12.0-Linux-x86_64.sh"
bash "Miniconda3-py38_4.12.0-Linux-x86_64.sh" -b -p ./miniconda
echo 'PATH=$PATH:~/miniconda/bin' >> ~/.bashrc
export PATH=$PATH:~/miniconda/bin
conda init

apt-get install jq
# install conda env reqs
git clone https://github.com/hector-baez/crux.git
conda install -n base -c anaconda cython
conda env update -f crux/env.yml -n base
