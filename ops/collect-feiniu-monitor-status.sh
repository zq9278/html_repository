#!/bin/sh
set -eu

OUT_DIR="/vol1/docker/feiniu-monitor-site/data"
OUT_FILE="$OUT_DIR/status.json"
TMP_FILE="$OUT_FILE.tmp"
PUBLIC_HOST="sanitlook.cn"
DMZ_CLIENT="192.168.3.181"

mkdir -p "$OUT_DIR"

json_escape() {
  awk 'BEGIN{ORS=""} {gsub(/\\/,"\\\\"); gsub(/"/,"\\\""); gsub(/\t/,"\\t"); gsub(/\r/,""); if (NR > 1) printf "\\n"; printf "%s", $0}'
}

emit_containers() {
  first=1
  docker ps -a --format '{{.Names}}|{{.Image}}|{{.Status}}|{{.Ports}}' | while IFS='|' read -r name image status ports; do
    [ -n "$name" ] || continue
    [ "$first" = 1 ] || printf ','
    first=0
    printf '{"name":"%s","image":"%s","status":"%s","ports":[' \
      "$(printf '%s' "$name" | json_escape)" \
      "$(printf '%s' "$image" | json_escape)" \
      "$(printf '%s' "$status" | json_escape)"
    port_first=1
    printf '%s' "$ports" | tr ',' '\n' | while read -r mapping; do
      host_port="$(printf '%s' "$mapping" | sed -n 's/.*0\.0\.0\.0:\([0-9][0-9]*\)->.*/\1/p' | head -1)"
      container_port="$(printf '%s' "$mapping" | sed -n 's/.*->\([^, ]*\).*/\1/p' | head -1)"
      [ -n "$host_port" ] || continue
      [ "$port_first" = 1 ] || printf ','
      port_first=0
      printf '{"host":"%s","container":"%s","public":true}' "$host_port" "$(printf '%s' "$container_port" | json_escape)"
    done
    printf ']}'
  done
}

site_name_for_port() {
  case "$1" in
    18080) printf 'SND 原型页' ;;
    18081) printf 'sanitlook 官网镜像' ;;
    18082) printf '杭州立诺康 SND100 官网' ;;
    18083) printf 'SND100 设计管理面板' ;;
    18084) printf '飞牛 Docker 实时监控' ;;
    *) printf 'Docker 网站 %s' "$1" ;;
  esac
}

site_path_for_port() {
  case "$1" in
    18080) printf '/vol1/docker/snd-site' ;;
    18081) printf '/vol1/docker/www-sanitlook-site' ;;
    18082) printf '/vol1/docker/snd100-linuokang-site' ;;
    18083) printf '/vol1/docker/snd100-dashboard-app' ;;
    18084) printf '/vol1/docker/feiniu-monitor-site' ;;
    *) printf '/vol1/docker' ;;
  esac
}

emit_sites() {
  ports="$(docker ps --format '{{.Ports}}' | tr ',' '\n' | sed -n 's/.*0\.0\.0\.0:\([0-9][0-9]*\)->80\/tcp.*/\1/p' | sort -n | uniq)"
  first=1
  for port in $ports; do
    [ "$first" = 1 ] || printf ','
    first=0
    code="$(curl -o /dev/null -s -m 5 -w '%{http_code}' "http://127.0.0.1:$port/" || true)"
    [ "$code" != "000" ] || code=""
    name="$(site_name_for_port "$port")"
    path="$(site_path_for_port "$port")"
    printf '{"name":"%s","port":%s,"path":"%s",' \
      "$(printf '%s' "$name" | json_escape)" "$port" "$(printf '%s' "$path" | json_escape)"
    if [ -n "$code" ]; then
      printf '"httpStatus":%s}' "$code"
    else
      printf '"error":"timeout"}'
    fi
  done
}

emit_ports() {
  first=1
  ss -tlnp 2>/dev/null | awk '
    NR > 1 {
      local=$4
      sub(/^.*:/, "", local)
      if (local == "80" || local == "443" || (local >= 18080 && local <= 18120)) {
        process="listen"
        if (match($0, /users:\(\(\("[^"]+"/)) {
          process=substr($0, RSTART + 10, RLENGTH - 10)
        }
        seen[local "|" process]=1
      }
    }
    END {
      for (item in seen) print item
    }
  ' | sort -n | while IFS='|' read -r port process; do
    [ -n "$process" ] || process="listen"
    [ "$first" = 1 ] || printf ','
    first=0
    printf '{"port":%s,"process":"%s","public":true}' "$port" "$(printf '%s' "$process" | json_escape)"
  done
}

timer_field() {
  systemctl "$1" "$2" 2>/dev/null || printf 'unknown'
}

emit_scripts() {
  first=1
  for path in \
    /usr/local/sbin/sync-html-repository.sh \
    /usr/local/sbin/collect-feiniu-monitor-status.sh \
    /usr/local/sbin/process-feiniu-monitor-actions.sh \
    /usr/local/sbin/renew-sanitlook-upnp.py \
    /etc/systemd/system/sync-html-repository.service \
    /etc/systemd/system/sync-html-repository.timer \
    /etc/systemd/system/feiniu-monitor-status.service \
    /etc/systemd/system/feiniu-monitor-status.timer \
    /etc/systemd/system/feiniu-monitor-actions.service \
    /etc/systemd/system/feiniu-monitor-actions.timer; do
    [ -e "$path" ] || continue
    [ "$first" = 1 ] || printf ','
    first=0
    name="$(basename "$path")"
    size="$(wc -c < "$path" | xargs)"
    modified="$(date -r "$path" '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null || true)"
    mode="$(stat -c '%a' "$path" 2>/dev/null || true)"
    printf '{"name":"%s","path":"%s","size":%s,"modified":"%s","mode":"%s"}' \
      "$(printf '%s' "$name" | json_escape)" \
      "$(printf '%s' "$path" | json_escape)" \
      "$size" \
      "$(printf '%s' "$modified" | json_escape)" \
      "$(printf '%s' "$mode" | json_escape)"
  done
}

emit_action_log() {
  if [ -f "$OUT_DIR/action-log.json" ]; then
    cat "$OUT_DIR/action-log.json"
  else
    printf '[]'
  fi
}

emit_folder_config() {
  if [ -f "$OUT_DIR/site-folders.json" ]; then
    cat "$OUT_DIR/site-folders.json"
  else
    printf '{"folders":["业务网站","管理工具","系统入口","其他网站"],"assignments":{}}'
  fi
}

generated_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
generated_local="$(date '+%Y-%m-%d %H:%M:%S %Z')"
hostname="$(hostname)"
ips="$(hostname -I | xargs)"
load="$(cut -d' ' -f1-3 /proc/loadavg)"
uptime_text="$(uptime -p 2>/dev/null || uptime)"
docker_size="$(du -sh /vol1/docker 2>/dev/null | awk '{print $1}')"
docker_version="$(docker --version 2>/dev/null | sed 's/,.*//')"
site_count="$(find /vol1/docker -maxdepth 2 \( -name index.html -o -name docker-compose.yml \) 2>/dev/null | sed 's#/[^/]*$##' | sort -u | wc -l | xargs)"
timer_active="$(timer_field is-active sync-html-repository.timer)"
timer_enabled="$(timer_field is-enabled sync-html-repository.timer)"
last_result="$(systemctl show sync-html-repository.service -p Result --value 2>/dev/null || true)"
last_commit="$(cd /vol1/docker/html_repository_sync 2>/dev/null && git log --oneline -1 2>/dev/null | sed 's/"/\\"/g' || true)"
next_run="$(systemctl list-timers sync-html-repository.timer --no-pager 2>/dev/null | awk 'NR==2 {print $1, $2, $3, $4}')"

{
  printf '{'
  printf '"generatedAt":"%s",' "$generated_at"
  printf '"generatedAtLocal":"%s",' "$(printf '%s' "$generated_local" | json_escape)"
  printf '"dmzClient":"%s",' "$DMZ_CLIENT"
  printf '"publicHost":"%s",' "$PUBLIC_HOST"
  printf '"siteCount":%s,' "$site_count"
  printf '"host":{'
  printf '"hostname":"%s",' "$(printf '%s' "$hostname" | json_escape)"
  printf '"ips":"%s",' "$(printf '%s' "$ips" | json_escape)"
  printf '"load":"%s",' "$(printf '%s' "$load" | json_escape)"
  printf '"uptime":"%s",' "$(printf '%s' "$uptime_text" | json_escape)"
  printf '"dockerSize":"%s",' "$(printf '%s' "$docker_size" | json_escape)"
  printf '"dockerVersion":"%s"},' "$(printf '%s' "$docker_version" | json_escape)"
  printf '"sync":{'
  printf '"timerActive":"%s",' "$(printf '%s' "$timer_active" | json_escape)"
  printf '"timerEnabled":"%s",' "$(printf '%s' "$timer_enabled" | json_escape)"
  printf '"lastResult":"%s",' "$(printf '%s' "$last_result" | json_escape)"
  printf '"lastCommit":"%s",' "$(printf '%s' "$last_commit" | json_escape)"
  printf '"nextRun":"%s"},' "$(printf '%s' "$next_run" | json_escape)"
  printf '"containers":['
  emit_containers
  printf '],"sites":['
  emit_sites
  printf '],"ports":['
  emit_ports
  printf '],"scripts":['
  emit_scripts
  printf '],"actions":'
  emit_action_log
  printf ',"folderConfig":'
  emit_folder_config
  printf '}'
} > "$TMP_FILE"

mv "$TMP_FILE" "$OUT_FILE"
