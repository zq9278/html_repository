FROM scratch

COPY busybox /busybox
COPY index.html /www/index.html
COPY --chmod=755 cgi-bin /www/cgi-bin

VOLUME ["/data"]
EXPOSE 80
CMD ["/busybox", "httpd", "-f", "-p", "80", "-h", "/www"]
