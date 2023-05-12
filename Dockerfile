FROM debian:11
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && apt install -y lvm2 qemu-utils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]
