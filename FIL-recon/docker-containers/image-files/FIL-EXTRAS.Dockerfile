ARG BASE_IMAGE=ubuntu:20.04
FROM $BASE_IMAGE


# Some useful general purpose tools
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends --no-install-suggests --yes \
    xterm \
    vim
    
# Allow access to the GPU
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES all 

# ROMEO phase unwrapping for B1 mapping
RUN cd /tmp && \
    wget https://github.com/korbinian90/ROMEO/releases/download/v3.2.5/romeo_linux_3.2.5.tar.gz && \
    sudo tar -xf romeo_linux_3.2.5.tar.gz -C /usr/local && \
    sudo rm romeo_linux_3.2.5.tar.gz && \
    sudo ln -s /usr/local/romeo_linux_3.2.5/bin/romeo /usr/local/bin/romeo

