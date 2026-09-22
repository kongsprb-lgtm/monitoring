# 🥚 Steal An Egg - Pure Joki Monitoring & Web Tracker

Script monitoring akun Roblox **Steal An Egg** via **Discord Webhook** & **Web Dashboard (p4kong.site)** dengan tampilan antarmuka **WindUI**. Dibuat oleh **P4kong x SysHub**.

> 🔒 **100% Pure Telemetry**: Script ini murni hanya membaca data statistik, tampilan HUD, dan isi tas/kandang tanpa memodifikasi input game, tanpa Anti-AFK, dan tanpa hook yang dicurigai anti-cheat (BAC-safe).

---

## ⚡ Loadstring Executor

Jalankan kode ini di executor kamu:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/kongsprb-lgtm/monitoring/main/steal_an_egg.lua"))()
```

---

## 🌐 Web Monitoring Dashboard

Kamu bisa memantau semua akun joki secara online langsung dari browser HP atau PC:

- **URL Dashboard**: [https://p4kong.site/monitoringjoki](https://p4kong.site/monitoringjoki)
- **PIN Akses**: `1802`

### Fitur di Web Dashboard:
1. **Status Online / Offline**: Menampilkan avatar Roblox, display name, username, ping, dan durasi monitoring sesi saat ini.
2. **Statistik Uang & Treadmill**: Menampilkan saldo **Money Sekarang** (misal `$50.2Qa`) dan kecepatan **Treadmill / Speed** (misal `187.77 B`).
3. **Pet di Kandang (Active)**: Menampilkan jumlah pet yang terpasang (19/19) beserta nama dan kuantitasnya.
4. **Egg di Backpack**: Menampilkan jumlah telur di tas beserta rincian jenis telurnya.
5. **Pet di Backpack**: Menampilkan jumlah pet di tas (100 pet) beserta rincian jenis petnya.
6. **Live Steal Feed**: Log notifikasi realtime saat akun mencuri telur baru (lengkap dengan Rarity, Earn Rate $/s, Multiplier Scale, Mutasi, dan waktu pencurian).
7. **Reset Otomatis**: Durasi monitoring berjalan saat script dieksekusi. Jika game/script mati, akun otomatis berstatus OFFLINE dan waktu akan di-reset saat dieksekusi kembali.

---

## 🎛️ Pengaturan di Menu Script (In-Game WindUI)

- **Tab Web Monitor**:
  - Toggle aktifkan pengiriman data ke `p4kong.site`.
  - Tombol **Kirim Update ke Web Sekarang** untuk sinkronisasi instan.
  - Tombol **Salin Link Dashboard** untuk menyalin link web ke clipboard.
- **Tab Webhook Discord**:
  - Input Webhook URL Discord dan Discord User ID (untuk mention).
  - Slider dan Preset Dropdown untuk memilih interval update otomatis (1 - 60 menit).
  - Checkbox pilihan data yang ingin dikirim ke Discord (Egg didapat, Egg backpack, Pet backpack, Pet kandang, Money, Speed).
  - Tombol uji coba pengiriman webhook.
- **Tab Live Stats**:
  - Pemantau statistik akun langsung di dalam game secara realtime.
