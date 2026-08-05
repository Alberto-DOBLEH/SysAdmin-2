FROM alpine:3.20

RUN apk add --no-cache nginx iputils \
    && addgroup -g 1000 webgroup \
    && adduser -D -H -u 1000 -G webgroup webuser \
    && mkdir -p /run/nginx /var/cache/nginx/client_temp /usr/share/nginx/html \
    && chown -R webuser:webgroup /run/nginx /var/cache/nginx /usr/share/nginx/html

COPY nginx.conf /etc/nginx/nginx.conf

USER webuser

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
