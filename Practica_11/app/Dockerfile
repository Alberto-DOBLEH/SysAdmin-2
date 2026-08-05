FROM alpine:3.20

RUN apk add --no-cache nginx \
    && addgroup -g 1001 appgroup \
    && adduser -D -H -u 1001 -G appgroup appuser \
    && mkdir -p /run/nginx /var/cache/nginx/client_temp /var/cache/nginx/proxy_temp /var/cache/nginx/fastcgi_temp /var/cache/nginx/uwsgi_temp /var/cache/nginx/scgi_temp /usr/share/nginx/html \
    && chown -R appuser:appgroup /run/nginx /var/cache/nginx /usr/share/nginx/html

COPY nginx.conf /etc/nginx/nginx.conf
COPY index.html /usr/share/nginx/html/index.html

USER appuser

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
