#!/bin/sh
set -eu

FTP_USER="${FTP_USER:-ftpadmin}"
FTP_PASSWORD="${FTP_PASSWORD:-SysAdmin10!}"
PASV_ADDRESS="${PASV_ADDRESS:-}"

if ! id "$FTP_USER" >/dev/null 2>&1; then
    adduser -D -h /home/ftpuser -s /sbin/nologin -u 1000 -G ftpgroup "$FTP_USER"
fi

echo "$FTP_USER:$FTP_PASSWORD" | chpasswd
chown -R "$FTP_USER:ftpgroup" /home/ftpuser/files

if [ -n "$PASV_ADDRESS" ] && ! grep -q '^pasv_address=' /etc/vsftpd/vsftpd.conf; then
    echo "pasv_address=$PASV_ADDRESS" >> /etc/vsftpd/vsftpd.conf
fi

exec /usr/sbin/vsftpd /etc/vsftpd/vsftpd.conf
