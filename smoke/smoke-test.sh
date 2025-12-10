#!/usr/bin/env bash
set -euo pipefail

URL="http://localhost:8080"

echo "Testing $URL ..."

for i in {1..10}; do
  if curl -sf "$URL" > /dev/null ; then
    echo "SMOKE PASSED" > smoke.log
    exit 0
  fi
  sleep 1
done

echo "SMOKE FAILED" > smoke.log
exit 1
