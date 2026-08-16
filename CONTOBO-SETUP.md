# Deploy Leonardo Auto Refresher ke Contabo VPS

Panduan lengkap setelah saldo Contabo sudah terisi.

## 1. Order VPS di Contabo

1. Klik **Create → VPS** di dashboard Contabo.
2. Pilih konfigurasi minimum yang direkomendasikan:
   - **Lokasi:** Asia (Singapore) — latensi paling kecil dari Indonesia.
   - **Image:** Ubuntu 22.04 LTS.
   - **Storage:** 100 GB SSD (default).
   - **RAM:** minimal **4 GB**, ideal **8 GB** supaya Chromium tidak `pthread_create` error.
3. Checkout dan bayar dari saldo €8.89 yang sudah ada.
4. Tunggu email berisi **IP address VPS** dan **password root**.

## 2. Ambil Secret dari Dashboard Admin Sultan AI

Buka halaman **Admin → Akun Leonardo** di preview Sultan AI, klik tombol **"Salin env vars"** atau **"Tampilkan secret"**.

Catat 3 nilai ini:

```bash
# Contoh (jangan copy nilai ini, isi dari dashboard sendiri)
SYNC_URL=https://xhkpbgeyhgjooosmcjwo.supabase.co/functions/v1/leonardo-refresher-sync
SUPABASE_ANON_KEY=sb_publishable_...
REFRESHER_SECRET=...
```

> `REFRESHER_SECRET` sama dengan `LEONARDO_REFRESH_SECRET` di backend.

## 3. Login ke VPS

Dari terminal PC/laptop:

```bash
ssh root@<IP-VPS-ANDA>
```

Ganti `<IP-VPS-ANDA>` dengan IP dari email Contabo. Password root juga ada di email.

## 4. Jalankan Script Setup Otomatis

Di dalam VPS, jalankan:

```bash
curl -fsSL https://raw.githubusercontent.com/<user>/<repo>/main/vps-leonardo-refresher/setup-contabo.sh -o setup-contabo.sh
chmod +x setup-contabo.sh
./setup-contabo.sh
```

Script akan:
- Update sistem dan install Docker.
- Buat folder `/opt/sultan-leo-refresher`.
- Meminta input `SYNC_URL`, `SUPABASE_ANON_KEY`, dan `REFRESHER_SECRET`.
- Menulis file `.env` dan `docker-compose.yml`.
- Pull image Playwright dan menjalankan service.
- Setup systemd auto-start jika VPS reboot.

## 5. Verifikasi Service Berjalan

```bash
# Cek container
docker ps

# Cek log realtime
docker logs -f sultan-leo-refresher

# Cek health endpoint
curl http://localhost:8080/health
```

Output sehat:

```json
{
  "ok": true,
  "configured": true,
  "version": "4.8.0"
}
```

## 6. Buka dari Admin Dashboard

1. Kembali ke **Admin → Akun Leonardo**.
2. Isi kolom **"URL VPS Refresher"** dengan: `http://<IP-VPS-ANDA>:8080`
3. Klik **"Test / Run Refresh"**.
4. Pantau log di VPS: `docker logs -f sultan-leo-refresher`.

## Troubleshooting

| Gejala | Penyebab | Solusi |
|---|---|---|
| `configured: false` | `.env` belum lengkap | Edit `/opt/sultan-leo-refresher/.env`, lalu `docker restart sultan-leo-refresher` |
| `pthread_create: Resource temporarily unavailable` | RAM/ thread habis | Naikkan RAM ke 8 GB atau turunkan `CONCURRENCY=1` |
| Akun tetap "Mati" | Proxy diblokir atau cookie rusak | Cek log, lalu refresh manual dari extension capture |
| Port 8080 tidak terbuka | Firewall Contabo | Buka port 8080 di **Contabo Firewall** (menu Network) |

## Update ke Versi Barer

Kalau nanti ada versi baru:

```bash
cd /opt/sultan-leo-refresher
docker pull mcr.microsoft.com/playwright:v1.62.1-jammy
docker compose down
docker compose up -d --build
```
