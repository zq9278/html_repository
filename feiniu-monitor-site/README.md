# Feiniu Docker Monitor

Read-only Docker and website monitor for the Feiniu OS host.

- Local URL: `http://192.168.3.181:18084/`
- Public URL: `http://sanitlook.cn:18084/`
- Data source: `/vol1/docker/feiniu-monitor-site/data/status.json`
- Refresh: host-side systemd timer updates data every minute; the browser reloads JSON every 15 seconds.

The web container does not mount Docker socket. Host information is collected by `/usr/local/sbin/collect-feiniu-monitor-status.sh`.
