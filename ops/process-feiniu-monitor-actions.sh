#!/bin/sh
set -eu

DATA_DIR="/vol1/docker/feiniu-monitor-site/data"
ACTIONS_DIR="$DATA_DIR/actions"
LOG_FILE="$DATA_DIR/action-log.json"
PASSWORD_FILE="/root/.config/feiniu_monitor_admin_password"
DELETED_DIR="/vol1/docker/_deleted-sites"

mkdir -p "$ACTIONS_DIR" "$DELETED_DIR"
[ -f "$PASSWORD_FILE" ] || exit 0

python3 - "$ACTIONS_DIR" "$LOG_FILE" "$PASSWORD_FILE" "$DELETED_DIR" <<'PY'
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

actions_dir = Path(sys.argv[1])
log_file = Path(sys.argv[2])
password_file = Path(sys.argv[3])
deleted_dir = Path(sys.argv[4])

SITES = {
    18080: {"name": "SND 原型页", "container": "snd-web", "path": Path("/vol1/docker/snd-site")},
    18081: {"name": "sanitlook 官网镜像", "container": "www-sanitlook-web", "path": Path("/vol1/docker/www-sanitlook-site")},
    18082: {"name": "杭州立诺康 SND100 官网", "container": "snd100-linuokang-web", "path": Path("/vol1/docker/snd100-linuokang-site")},
    18083: {"name": "SND100 设计管理面板", "container": "snd100-dashboard-app", "path": Path("/vol1/docker/snd100-dashboard-app")},
}


def load_log():
    if not log_file.exists():
        return []
    try:
        data = json.loads(log_file.read_text(encoding="utf-8"))
        return data if isinstance(data, list) else []
    except Exception:
        return []


def save_log(entries):
    log_file.write_text(json.dumps(entries[-80:], ensure_ascii=False, indent=2), encoding="utf-8")


def run(args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=60)


password = password_file.read_text(encoding="utf-8").strip()
entries = load_log()

for request_file in sorted(actions_dir.glob("request-*.json")):
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    entry = {"time": now, "file": request_file.name, "ok": False}
    try:
        payload = json.loads(request_file.read_text(encoding="utf-8"))
        action = payload.get("action")
        port = int(payload.get("port"))
        entry.update({"action": action, "port": port})

        if payload.get("password") != password:
            entry["error"] = "密码错误"
        elif action != "delete_site":
            entry["error"] = "未知动作"
        elif port not in SITES:
            entry["error"] = "此站点不允许在网页中删除"
        else:
            site = SITES[port]
            container = site["container"]
            site_path = site["path"]
            stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
            backup_path = deleted_dir / f"{stamp}-{site_path.name}"

            rm = run(["docker", "rm", "-f", container])
            if rm.returncode != 0:
                entry["error"] = f"停止容器失败: {rm.stdout.strip()[:300]}"
            else:
                if site_path.exists():
                    shutil.move(str(site_path), str(backup_path))
                    entry["backupPath"] = str(backup_path)
                entry.update({"ok": True, "name": site["name"], "container": container})
    except Exception as exc:
        entry["error"] = str(exc)
    finally:
        entries.append(entry)
        try:
            request_file.unlink()
        except FileNotFoundError:
            pass

save_log(entries)
PY

/usr/local/sbin/collect-feiniu-monitor-status.sh
