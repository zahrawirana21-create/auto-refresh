#!/bin/bash
# Sultan AI — Leonardo Auto Refresher setup untuk Contabo VPS (Ubuntu)
set -e

echo "=============================================="
echo "  Sultan AI Leonardo Refresher — Setup VPS"
echo "=============================================="

# --- 1. Update sistem & install Docker ---
echo "[1/6] Update sistem dan install Docker..."
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release

if ! command -v docker &> /dev/null; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi

# --- 2. Buat direktori aplikasi ---
APP_DIR="/opt/sultan-leo-refresher"
mkdir -p "$APP_DIR"
cd "$APP_DIR"

echo "[2/6] Direktori aplikasi: $APP_DIR"

# --- 3. Download file service ---
echo "[3/6] Download file refresher..."
REPO_RAW="https://raw.githubusercontent.com/lovable-dev/sultan-ai/main/vps-leonardo-refresher"
# Fallback: jika repo public tidak tersedia, user bisa upload manual file server.js, package.json, Dockerfile
for f in server.js package.json Dockerfile; do
  if [ -f "$f" ]; then
    echo "  $f sudah ada, lewati."
  else
    curl -fsSL "$REPO_RAW/$f" -o "$f" || echo "  ⚠️  Gagal download $f — salin manual ke $APP_DIR"
  fi
done

# --- 4. Input secret ---
echo "[4/6] Masukkan konfigurasi backend:"
read -rp "SYNC_URL (contoh: https://xxxx.supabase.co/functions/v1/leonardo-refresher-sync): " SYNC_URL
read -rp "SUPABASE_ANON_KEY: " SUPABASE_ANON_KEY
read -rsp "REFRESHER_SECRET (sama dengan LEONARDO_REFRESH_SECRET): " REFRESHER_SECRET
echo

# Validasi minimal
if [ -z "$SYNC_URL" ] || [ -z "$SUPABASE_ANON_KEY" ] || [ -z "$REFRESHER_SECRET" ]; then
  echo "❌ Semua nilai wajib diisi. Ulangi script."
  exit 1
fi

# --- 5. Tulis .env ---
echo "[5/6] Menulis konfigurasi..."
cat > "$APP_DIR/.env" <<EOF
SYNC_URL=${SYNC_URL%/}
SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
REFRESHER_SECRET=$REFRESHER_SECRET
CONTROL_SECRET=$REFRESHER_SECRET
CYCLE_INTERVAL_MS=120000
ACCOUNT_COOLDOWN_MS=900000
FAIL_COOLDOWN_MS=60000
PAGE_WAIT_MS=30000
CHECKPOINT_WAIT_MS=75000
MAX_PER_CYCLE=20
MAX_ACCOUNTS_PER_CYCLE=3
CONCURRENCY=1
ACCOUNT_RETRIES=3
BOOT_DELAY_MS=15000
USE_PROXY=1
EOF

chmod 600 "$APP_DIR/.env"

# --- 6. Tulis docker-compose.yml ---
cat > "$APP_DIR/docker-compose.yml" <<'EOF'
services:
  refresher:
    build: .
    container_name: sultan-leo-refresher
    restart: always
    env_file: .env
    ports:
      - "8080:8080"
    logging:
      driver: "json-file"
      options:
        max-size: "50m"
        max-file: "3"
EOF

# --- 7. Build & jalankan ---
echo "[6/6] Build dan jalankan container..."
docker compose down 2>/dev/null || true
docker compose up -d --build

# --- 8. Setup systemd auto-restart Docker (opsional tapi direkomendasikan) ---
if [ ! -f /etc/systemd/system/sultan-leo-refresher.service ]; then
  cat > /etc/systemd/system/sultan-leo-refresher.service <<EOF
[Unit]
Description=Sultan AI Leonardo Refresher
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable sultan-leo-refresher.service
fi

# --- 9. Tunggu health ---
echo "Menunggu service siap..."
for i in {1..30}; do
  if curl -sf http://localhost:8080/health > /dev/null 2>&1; then
    echo "✅ Service sudah aktif!"
    break
  fi
  sleep 2
done

echo ""
echo "=============================================="
echo "  Setup selesai"
echo "=============================================="
echo "Health check:  curl http://localhost:8080/health"
echo "Logs realtime: docker logs -f sultan-leo-refresher"
echo "Restart:       docker restart sultan-leo-refresher"
echo ""
echo "Masukkan IP VPS ini ke Admin Dashboard Sultan AI:"
echo "  http://$(hostname -I | awk '{print $1}'):8080"
