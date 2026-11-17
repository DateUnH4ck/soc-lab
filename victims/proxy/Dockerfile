# srv-proxy: proxy de salida de la empresa (Squid) con agente Wazuh.
# Todo lo que se navega a través de él queda en /var/log/squid/access.log.
# Base: imagen oficial del agente Wazuh (Amazon Linux 2023, multi-arquitectura).
ARG WAZUH_VERSION=4.14.9
FROM wazuh/wazuh-agent:${WAZUH_VERSION}

RUN yum install -y squid && yum clean all && rm -rf /var/cache/yum

COPY ossec.conf /wazuh-config-mount/etc/ossec.conf
COPY rootfs/ /

RUN chmod +x /etc/cont-init.d/01-lab-init /etc/services.d/*/run

EXPOSE 3128
