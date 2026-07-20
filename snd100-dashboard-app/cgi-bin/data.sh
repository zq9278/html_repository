#!/busybox sh

DATA_FILE="/data/dashboard.json"

if [ "$REQUEST_METHOD" = "POST" ]; then
  mkdir -p /data
  if [ -n "$CONTENT_LENGTH" ] && [ "$CONTENT_LENGTH" -gt 0 ] 2>/dev/null; then
    /busybox dd bs=1 count="$CONTENT_LENGTH" of="$DATA_FILE" 2>/dev/null
  else
    /busybox cat > "$DATA_FILE"
  fi
  /busybox printf "Content-Type: application/json; charset=utf-8\r\n"
  /busybox printf "Cache-Control: no-store\r\n"
  /busybox printf "Content-Length: 11\r\n\r\n"
  /busybox printf '{"ok":true}'
  exit 0
fi

if [ -f "$DATA_FILE" ]; then
  size="$(/busybox wc -c < "$DATA_FILE")"
  /busybox printf "Content-Type: application/json; charset=utf-8\r\n"
  /busybox printf "Cache-Control: no-store\r\n"
  /busybox printf "Content-Length: %s\r\n\r\n" "$size"
  /busybox cat "$DATA_FILE"
else
  /busybox printf "Content-Type: application/json; charset=utf-8\r\n"
  /busybox printf "Cache-Control: no-store\r\n"
  /busybox printf "Content-Length: 13\r\n\r\n"
  /busybox printf '{"data":null}'
fi
