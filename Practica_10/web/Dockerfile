FROM alpine:3.20

RUN apk add --no-cache nginx iputils \
    && mkdir -p /run/nginx /var/cache/nginx/client_temp /usr/share/nginx/html

COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
