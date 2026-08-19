#!/bin/bash
set -a
[ -f /etc/environment ] && source /etc/environment
set +a

service nginx start || true
exec node api/index.js
