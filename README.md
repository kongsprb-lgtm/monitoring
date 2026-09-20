# 🥚 Steal An Egg - Joki Account Monitoring

Script tracker dan monitoring perkembangan akun Roblox game **Steal An Egg** secara otomatis via **Discord Webhook** atau **Web Dashboard**.

---

## ⚡ Cara Cepat: Monitor via Discord Webhook

Kamu bisa langsung menjalankan script ini di emulator / executor (Delta, Fluxus, Codex, Arceus X, Synapse, dll).

### 1. Buat Webhook di Discord
1. Masuk ke server Discord kamu > Pilih channel monitoring > Klik ikon **Settings (Gerigi)**.
2. Pilih menu **Integrations** > **Webhooks** > **New Webhook**.
3. Copy URL Webhook tersebut.

### 2. Jalankan di Executor (Loadstring)
Copy dan jalankan kode ini di executor kamu:

```lua
-- Konfigurasi
getgenv().WebhookUrl = "GANTI_DENGAN_WEBHOOK_DISCORD_KAMU"
getgenv().Interval = 300 -- Kirim update tiap 5 menit (300 detik)

-- Loadstring
loadstring(game:HttpGet("https://raw.githubusercontent.com/kongsprb-lgtm/monitoring/main/steal_an_egg.lua"))()
```

> **Catatan:** Jangan bagikan link Webhook Discord kamu ke publik. Dengan format di atas, script inti tetap aman di GitHub dan kamu hanya perlu memasukkan webhook di executor masing-masing akun joki.

---

## 🌐 Cara Alternatif: Monitor via Web Dashboard Sendiri

Jika kamu mengelola banyak akun dan ingin tampilan web portal live:

### 1. Jalankan Server Web (Lokal / VPS)
Masuk ke folder `web`:
```bash
cd web
npm install
npm start
```
Buka browser di `http://localhost:3000`.

### 2. Jalankan Script di Executor
```lua
-- Kirim data ke Web Dashboard
getgenv().ServerUrl = "http://IP_SERVER_ATAU_DOMAIN:3000/api/update"
getgenv().Interval = 60 -- update tiap 1 menit

loadstring(game:HttpGet("https://raw.githubusercontent.com/kongsprb-lgtm/monitoring/main/steal_an_egg.lua"))()
```

---

## 🛠️ Fitur Script

- ✅ **One-Line Loadstring**: Cukup 1 baris untuk eksekusi lewat GitHub raw.
- ✅ **Auto-Detect Stats**: Otomatis mendeteksi Level, Uang (Cash), Kecepatan/Sepatu (Speed), dan Leaderstats.
- ✅ **Built-in Anti-AFK**: Otomatis mencegah akun ter-kick dari Roblox setelah 20 menit idle.
- ✅ **Uptime & Ping Tracker**: Mengetahui berapa lama joki sudah berjalan dan kestabilan koneksi server.
- ✅ **Multi-Account Friendly**: Bisa dijalankan di banyak emulator/tab sekaligus tanpa bentrok.
