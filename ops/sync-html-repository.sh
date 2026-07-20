#!/bin/sh
set -eu

REPO_URL="https://github.com/zq9278/html_repository.git"
REPO_DIR="/vol1/docker/html_repository_sync"
TOKEN_FILE="/root/.config/html_repository_github_token"
BRANCH="main"

if [ -f "$TOKEN_FILE" ]; then
  TOKEN="$(tr -d '\r\n' < "$TOKEN_FILE")"
  if [ -n "$TOKEN" ]; then
    REPO_URL="https://x-access-token:${TOKEN}@github.com/zq9278/html_repository.git"
  fi
fi

if [ ! -d "$REPO_DIR/.git" ]; then
  rm -rf "$REPO_DIR"
  git clone "$REPO_URL" "$REPO_DIR"
fi

cd "$REPO_DIR"
git remote set-url origin "$REPO_URL"
git fetch origin "$BRANCH"
git checkout "$BRANCH"
git reset --hard "origin/$BRANCH"

copy_site() {
  src="$1"
  dst="$2"
  if [ -d "$src" ]; then
    mkdir -p "$dst"
    cp -a "$src"/. "$dst"/
  fi
}

copy_site "/vol1/docker/snd-site" "$REPO_DIR/snd-site"
copy_site "/vol1/docker/www-sanitlook-site" "$REPO_DIR/www-sanitlook-site"
copy_site "/vol1/docker/snd100-linuokang-site" "$REPO_DIR/snd100-linuokang-site"
copy_site "/vol1/docker/snd100-dashboard-app" "$REPO_DIR/snd100-dashboard-app"

git config user.name "zq-nas"
git config user.email "zq9278@gmail.com"
git add snd-site www-sanitlook-site snd100-linuokang-site snd100-dashboard-app

if git diff --cached --quiet; then
  echo "No changes to sync."
  exit 0
fi

git commit -m "Sync Feiniu Docker sites and data"
git push origin "$BRANCH"
