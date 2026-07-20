#!/busybox sh

DATA_FILE="/data/dashboard.json"

if [ "$REQUEST_METHOD" = "POST" ]; then
  mkdir -p /data
  if [ -n "$CONTENT_LENGTH" ] && [ "$CONTENT_LENGTH" -gt 0 ] 2>/dev/null; then
    /busybox dd bs=1 count="$CONTENT_LENGTH" of="$DATA_FILE" 2>/dev/null
  else
    /busybox cat > "$DATA_FILE"
  fi
  echo "Status: 204 No Content"
  echo
  exit 0
fi

echo "Content-Type: application/json; charset=utf-8"
echo "Cache-Control: no-store"
echo

if [ -f "$DATA_FILE" ]; then
  /busybox cat "$DATA_FILE"
else
  echo '{"data":null}'
fi
