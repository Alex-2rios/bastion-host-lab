FROM debian:13-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        openssh-server \
        iproute2 \
        iputils-ping \
        netcat-openbsd \
        default-mysql-client \
        tcpdump \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash jump \
    && mkdir -p /home/jump/.ssh /run/sshd \
    && chmod 700 /home/jump/.ssh \
    && chown -R jump:jump /home/jump/.ssh \
    && usermod -p '*' jump \
    && passwd -l root

COPY banner /etc/ssh/banner
COPY sshd_config /etc/ssh/sshd_config
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 22

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/sbin/sshd", "-D", "-e"]
