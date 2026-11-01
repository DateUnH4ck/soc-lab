# attacker: Kali Linux con las herramientas que usamos en el curso.
# kalilinux/kali-rolling es multi-arquitectura (amd64 y arm64).
FROM kalilinux/kali-rolling

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        nmap hydra nikto curl wget sshpass openssh-client \
        iputils-ping dnsutils netcat-traditional ncat whatweb \
        python3 python3-requests vim-tiny less ca-certificates && \
    rm -rf /var/lib/apt/lists/*

COPY wordlists/ /root/wordlists/
COPY motd /etc/motd
RUN echo 'cat /etc/motd' >> /root/.bashrc

WORKDIR /root
