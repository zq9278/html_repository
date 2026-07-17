FROM scratch

COPY busybox /busybox
COPY index.html /www/index.html
COPY assets /www/assets

EXPOSE 80
CMD ["/busybox", "httpd", "-f", "-p", "80", "-h", "/www"]
