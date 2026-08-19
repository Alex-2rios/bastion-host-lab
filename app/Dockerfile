FROM debian:12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        openssh-server \
        iproute2 \
        iputils-ping \
        netcat-openbsd \
        default-mysql-client \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash deploy \
    && mkdir -p /home/deploy/.ssh /run/sshd \
    && chmod 700 /home/deploy/.ssh \
    && chown -R deploy:deploy /home/deploy/.ssh \
    && usermod -p '*' deploy \
    && passwd -l root

COPY sshd_config /etc/ssh/sshd_config
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 22

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/sbin/sshd", "-D", "-e"]
