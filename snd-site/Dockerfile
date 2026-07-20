FROM scratch

COPY busybox /busybox
COPY index.html /www/index.html

EXPOSE 80
CMD ["/busybox", "httpd", "-f", "-p", "80", "-h", "/www"]
