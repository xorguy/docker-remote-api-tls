# Original Dockerfile: https://github.com/nginxinc/docker-nginx/blob/b0e153a1b644ca8b2bd378b14913fff316e07cf2/stable/alpine/Dockerfile
FROM nginx:1.30.6-alpine
LABEL org.opencontainers.image.authors="Kevin Krummenauer <kevin@whiledo.de>" \
      org.opencontainers.image.title="docker-remote-api-tls" \
      org.opencontainers.image.description="Docker Remote API secured with mutual TLS via nginx" \
      org.opencontainers.image.licenses="MIT"
# upgrade base packages to pick up security fixes released after the base image
RUN apk upgrade --no-cache && apk add --no-cache openssl

COPY resources/create-certs.sh /script/create-certs.sh
COPY resources/nginx-cert.conf /etc/nginx/nginx.conf
COPY resources/entrypoint.sh /docker-entrypoint.d/30_entrypoint.sh

RUN chmod +x /script/create-certs.sh /docker-entrypoint.d/30_entrypoint.sh

ENV CREATE_CERTS_WITH_PW="" \
    CERTS_DIR=/data/certs \
    CERT_HOSTNAME="abc.127.0.0.1.nip.io" \
    CERT_EXPIRATION_DAYS="365" \
    CA_EXPIRATION_DAYS="900"

HEALTHCHECK --start-period=1s \
            --interval=5s \
            --timeout=5s \
            --retries=12 \
            CMD nc -vz 127.0.0.1 443 || exit 1
