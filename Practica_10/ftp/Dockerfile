FROM alpine:3.20

RUN apk add --no-cache vsftpd \
    && mkdir -p /home/ftpuser/files /var/run/vsftpd/empty \
    && addgroup -g 1000 ftpgroup \
    && chown -R root:ftpgroup /home/ftpuser \
    && chmod -R 775 /home/ftpuser

COPY vsftpd.conf /etc/vsftpd/vsftpd.conf
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 21 21100-21110

ENTRYPOINT ["/entrypoint.sh"]
