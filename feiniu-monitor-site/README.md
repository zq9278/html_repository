# Feiniu Docker Monitor

Read-only Docker and website monitor for the Feiniu OS host.

- Local URL: `http://192.168.3.181:18084/`
- Public URL: `http://sanitlook.cn:18084/`
- Data source: `/vol1/docker/feiniu-monitor-site/data/status.json`
- Refresh: host-side systemd timer updates data every minute; the browser reloads JSON every 15 seconds.

The web container does not mount Docker socket. Host information is collected by `/usr/local/sbin/collect-feiniu-monitor-status.sh`.

## Admin Actions

The monitor can queue delete requests through `/cgi-bin/action.sh`. Requests are processed by the host-side timer:

- `/usr/local/sbin/process-feiniu-monitor-actions.sh`
- `feiniu-monitor-actions.service`
- `feiniu-monitor-actions.timer`

The admin password is stored only on the Feiniu host:

- `/root/.config/feiniu_monitor_admin_password`

Delete requests stop the Docker container and move the site folder into `/vol1/docker/_deleted-sites`. The monitor site on port `18084` is protected and cannot delete itself from the web UI.

The website list is grouped like folders. Current default groups are business websites, management tools, system entries, and other websites. Users can create folders and move sites between folders from the monitor UI; changes are stored in `/vol1/docker/feiniu-monitor-site/data/site-folders.json`.
