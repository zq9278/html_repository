FROM scratch
COPY busybox /busybox
COPY index.html /www/index.html
COPY data /www/data
COPY --chmod=755 cgi-bin /www/cgi-bin
EXPOSE 80
CMD ["/busybox", "httpd", "-f", "-p", "80", "-h", "/www"]
