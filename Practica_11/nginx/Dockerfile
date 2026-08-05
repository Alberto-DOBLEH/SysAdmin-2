FROM alpine:3.20

RUN apk add --no-cache nginx iputils \
    && addgroup -g 1000 nginxapp \
    && adduser -D -H -u 1000 -G nginxapp nginxapp \
    && mkdir -p /run/nginx /var/cache/nginx/client_temp /var/cache/nginx/proxy_temp /var/cache/nginx/fastcgi_temp /var/cache/nginx/uwsgi_temp /var/cache/nginx/scgi_temp /usr/share/nginx/html \
    && chown -R nginxapp:nginxapp /run/nginx /var/cache/nginx /usr/share/nginx/html

COPY nginx.conf /etc/nginx/nginx.conf
COPY site/ /usr/share/nginx/html/

USER nginxapp

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
