# srv-ssh: servidor Linux con SSH y agente Wazuh.
# Base: imagen oficial del agente Wazuh (Amazon Linux 2023, multi-arquitectura).
ARG WAZUH_VERSION=4.14.9
FROM wazuh/wazuh-agent:${WAZUH_VERSION}

RUN yum install -y openssh-server rsyslog sudo shadow-utils iptables-nft && \
    yum clean all && rm -rf /var/cache/yum

COPY ossec.conf /wazuh-config-mount/etc/ossec.conf
COPY rootfs/ /

# Usuarios del laboratorio. La contraseña de "soporte" es DEBIL A PROPOSITO:
# este contenedor solo es accesible desde la red interna del laboratorio.
# Ademas, pam_loginuid falla dentro de contenedores: lo hacemos opcional.
RUN useradd -m -s /bin/bash soporte && echo 'soporte:sunshine' | chpasswd && \
    useradd -m -s /bin/bash jonathas && echo 'jonathas:Cambi4Esto!2026' | chpasswd && \
    usermod -aG wheel jonathas && \
    sed -i 's/^session\s\+required\s\+pam_loginuid.so/session optional pam_loginuid.so/' /etc/pam.d/sshd && \
    chmod +x /etc/cont-init.d/01-lab-init /etc/services.d/*/run

EXPOSE 22
