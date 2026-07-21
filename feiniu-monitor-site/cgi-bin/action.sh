#!/busybox sh

ACTIONS_DIR="/www/data/actions"

reply() {
  body="$1"
  size="$(/busybox printf '%s' "$body" | /busybox wc -c)"
  /busybox printf "Content-Type: application/json; charset=utf-8\r\n"
  /busybox printf "Cache-Control: no-store\r\n"
  /busybox printf "Content-Length: %s\r\n\r\n" "$size"
  /busybox printf '%s' "$body"
}

if [ "$REQUEST_METHOD" != "POST" ]; then
  reply '{"ok":false,"error":"POST only"}'
  exit 0
fi

if [ -z "$CONTENT_LENGTH" ] || [ "$CONTENT_LENGTH" -le 0 ] 2>/dev/null || [ "$CONTENT_LENGTH" -gt 4096 ] 2>/dev/null; then
  reply '{"ok":false,"error":"invalid body size"}'
  exit 0
fi

/busybox mkdir -p "$ACTIONS_DIR"
tmp="$ACTIONS_DIR/request-$(/busybox date +%s)-$$.json"
/busybox cat > "$tmp"
/busybox chmod 600 "$tmp"
reply '{"ok":true,"message":"request queued"}'
