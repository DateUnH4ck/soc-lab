# capture: tcpdump mínimo para capturar el tráfico de un contenedor del lab.
# Se usa con ./lab.sh capture <servicio> [segundos]; el .pcap queda en ./captures
# y se abre con Wireshark en tu ordenador. Multi-arquitectura (amd64 y arm64).
FROM alpine:3.20
RUN apk add --no-cache tcpdump
