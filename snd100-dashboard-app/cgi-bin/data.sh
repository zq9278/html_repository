#!/busybox sh

DATA_FILE="/data/dashboard.json"

if [ "$REQUEST_METHOD" = "POST" ]; then
  mkdir -p /data
  if [ -n "$CONTENT_LENGTH" ] && [ "$CONTENT_LENGTH" -gt 0 ] 2>/dev/null; then
    /busybox dd bs=1 count="$CONTENT_LENGTH" of="$DATA_FILE" 2>/dev/null
  else
    /busybox cat > "$DATA_FILE"
  fi
  /busybox printf "Status: 204 No Content\r\n\r\n"
  exit 0
fi

/busybox printf "Content-Type: application/json; charset=utf-8\r\n"
/busybox printf "Cache-Control: no-store\r\n\r\n"

if [ -f "$DATA_FILE" ]; then
  /busybox cat "$DATA_FILE"
else
  echo '{"data":null}'
fi
