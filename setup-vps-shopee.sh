#!/bin/bash
# Sultan AI — Leonardo Auto Refresher
# Setup 1 VPS (Ubuntu 22.04, 8GB RAM / 4 core) tanpa Docker.
# Jalankan sebagai root:  bash setup-vps-shopee.sh
set -e

APP_DIR="/opt/sultan-leo-refresher"
echo "=============================================="
echo "  Sultan AI Leonardo Refresher — Setup VPS"
echo "=============================================="

echo "[1/6] Update sistem & dependensi dasar..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl ca-certificates gnupg git

echo "[2/6] Install Node.js 20..."
if ! command -v node >/dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
fi
node -v

echo "[3/6] Siapkan folder aplikasi ($APP_DIR)..."
mkdir -p "$APP_DIR"
cd "$APP_DIR"

if [ ! -f server.js ]; then
  echo "  ⚠️  server.js belum ada."
  echo "     Upload server.js + package.json ke $APP_DIR (via WinSCP/scp), lalu jalankan script ini lagi."
  exit 1
fi

echo "[4/6] Install dependensi Node + Chromium (Playwright)..."
npm install --omit=dev
npx playwright install --with-deps chromium

echo "[5/6] Konfigurasi backend..."
if [ -f .env ]; then
  echo "  .env sudah ada, dipakai ulang. Hapus dulu kalau mau ganti."
else
  read -rp "SYNC_URL: " SYNC_URL
  read -rp "SUPABASE_ANON_KEY: " SUPABASE_ANON_KEY
  read -rsp "REFRESHER_SECRET: " REFRESHER_SECRET; echo
  if [ -z "$SYNC_URL" ] || [ -z "$SUPABASE_ANON_KEY" ] || [ -z "$REFRESHER_SECRET" ]; then
    echo "❌ Semua nilai wajib diisi."; exit 1
  fi
  cat > .env <<EOF
SYNC_URL=${SYNC_URL%/}
SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
REFRESHER_SECRET=$REFRESHER_SECRET
CONTROL_SECRET=$REFRESHER_SECRET
PORT=8080
CYCLE_INTERVAL_MS=120000
ACCOUNT_COOLDOWN_MS=900000
FAIL_COOLDOWN_MS=60000
PAGE_WAIT_MS=30000
CHECKPOINT_WAIT_MS=75000
MAX_PER_CYCLE=40
MAX_ACCOUNTS_PER_CYCLE=8
CONCURRENCY=2
ACCOUNT_RETRIES=3
BOOT_DELAY_MS=10000
USE_PROXY=1
SHARD_TOTAL=1
SHARD_INDEX=0
WORKER_NAME=vps-shopee
HEARTBEAT_MS=20000
EOF
  chmod 600 .env
fi

echo "[6/6] Jalankan service dengan systemd..."
cat > /etc/systemd/system/sultan-leo-refresher.service <<EOF
[Unit]
Description=Sultan AI Leonardo Refresher
After=network-online.target

[Service]
Type=simple
WorkingDirectory=$APP_DIR
EnvironmentFile=$APP_DIR/.env
ExecStart=/usr/bin/node $APP_DIR/server.js
Restart=always
RestartSec=5
MemoryMax=6G

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now sultan-leo-refresher

echo "Menunggu service siap..."
for i in $(seq 1 30); do
  if curl -sf http://localhost:8080/health >/dev/null 2>&1; then echo "✅ Service aktif!"; break; fi
  sleep 2
done

echo ""
echo "Health : curl http://localhost:8080/health"
echo "Log    : journalctl -u sultan-leo-refresher -f"
echo "Restart: systemctl restart sultan-leo-refresher"
echo "URL utk Admin Dashboard: http://$(curl -s -4 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}'):8080"
