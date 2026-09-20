# 🥚 Steal An Egg - Webhook Tracker (WindUI Edition)

Script monitoring & webhook tracker otomatis untuk game **Steal An Egg** di Roblox dengan tampilan UI **WindUI** (persis seperti SysHub).

---

## ⚡ Cara Menjalankan (Loadstring)

Cukup copy 1 baris ini dan jalankan di executor kamu (Delta, Fluxus, Codex, Arceus X, dll):

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/kongsprb-lgtm/monitoring/main/steal_an_egg.lua"))()
```

> ⚠️ **PENTING:** Pastikan repository GitHub `kongsprb-lgtm/monitoring` kamu sudah di-set ke **PUBLIC** di GitHub Settings agar executor bisa membaca file raw-nya.

---

## 🖥️ Fitur UI & Pengaturan

Setelah script di-execute, jendela UI **WindUI** akan otomatis muncul di layar game:

1. **Webhook URL**: Tempelkan URL webhook Discord kamu di kolom ini.
2. **Discord User ID**: Masukkan User ID Discord kamu jika ingin di-mention/ping saat ada drop langka.
3. **Filter Rarity**: Pilih rarity mana saja yang ingin dilaporkan ke Discord (Multi-select).
4. **Toggles**:
   - `Webhook On Egg Spawn (Grouped)`: Memberikan info batch saat telur muncul di field.
   - `Webhook On Steal (To Backpack)`: Mengirim laporan saat berhasil mencuri telur ke backpack.
   - `Webhook On Hatch (Pet Result)`: Mengirim laporan saat telur berhasil di-hatch jadi pet.
5. **Test Buttons**:
   - `Test Spawn Batch Format` (Hijau)
   - `Test Hatch Format` (Biru)
6. **Auto Save Config**: Pengaturan dan URL Webhook kamu otomatis tersimpan di storage executor, jadi tidak perlu diketik ulang saat rejoin!
7. **Built-in Anti-AFK**: Mencegah akun ter-kick dari Roblox saat ditinggal AFK farming.
