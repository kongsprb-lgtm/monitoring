const express = require('express');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;
const ACCESS_PIN = "1802";

app.use(express.json());
app.use((req, res, next) => {
    res.header('Access-Control-Allow-Origin', '*');
    res.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    if (req.method === 'OPTIONS') {
        return res.sendStatus(204);
    }
    next();
});
app.use(express.static(path.join(__dirname, 'public')));

// In-memory data storage
const accounts = new Map();
const stealEvents = [];
const MAX_STEAL_EVENTS = 50;

// Route untuk halaman dashboard joki
app.get('/monitoringjoki', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Redirect root ke /monitoringjoki
app.get('/', (req, res) => {
    res.redirect('/monitoringjoki');
});

// Endpoint untuk verifikasi PIN (1802)
app.post('/api/verify-pin', (req, res) => {
    const { pin } = req.body;
    if (pin === ACCESS_PIN) {
        return res.json({ success: true, message: 'PIN Valid' });
    }
    return res.status(401).json({ success: false, error: 'PIN salah!' });
});

// Endpoint untuk menerima pembaruan statistik akun dari script Roblox
app.post('/api/update', (req, res) => {
    const {
        username,
        displayName,
        userId,
        uptime,
        ping,
        money,
        speed,
        level,
        petKandangCount,
        petsInKandang,
        eggBackpackCount,
        eggsInBackpack,
        petBackpackCount,
        petsInBackpack
    } = req.body;

    if (!username) {
        return res.status(400).json({ error: 'Username diperlukan' });
    }

    accounts.set(username, {
        username,
        displayName: displayName || username,
        userId: userId || 0,
        uptime: uptime || 'N/A',
        ping: ping || 'N/A',
        money: money || '$0',
        speed: speed || '0',
        level: level || 'N/A',
        petKandangCount: Number(petKandangCount) || 0,
        petsInKandang: typeof petsInKandang === 'object' && petsInKandang !== null ? petsInKandang : {},
        eggBackpackCount: Number(eggBackpackCount) || 0,
        eggsInBackpack: typeof eggsInBackpack === 'object' && eggsInBackpack !== null ? eggsInBackpack : {},
        petBackpackCount: Number(petBackpackCount) || 0,
        petsInBackpack: typeof petsInBackpack === 'object' && petsInBackpack !== null ? petsInBackpack : {},
        lastSeen: Date.now()
    });

    console.log(`[Update Akun] ${displayName} (@${username}) - Money: ${money} | Speed: ${speed}`);
    res.json({ success: true });
});

// Endpoint untuk menerima notifikasi realtime saat telur dicuri
app.post('/api/steal-event', (req, res) => {
    const {
        username,
        displayName,
        userId,
        eggName,
        rarity,
        earnRate,
        scale,
        mutations,
        timestamp
    } = req.body;

    if (!eggName) {
        return res.status(400).json({ error: 'Data telur tidak lengkap' });
    }

    const event = {
        id: Date.now() + '-' + Math.random().toString(36).substring(2, 7),
        username: username || 'Unknown',
        displayName: displayName || username || 'Unknown',
        userId: userId || 0,
        eggName: eggName || 'Telur',
        rarity: rarity || 'Common',
        earnRate: earnRate || 0,
        scale: scale || '1.00',
        mutations: mutations || 'None',
        timestamp: timestamp || Date.now()
    };

    stealEvents.unshift(event);
    if (stealEvents.length > MAX_STEAL_EVENTS) {
        stealEvents.pop();
    }

    console.log(`[Steal Event] ${displayName} mencuri ${eggName} (${rarity})`);
    res.json({ success: true });
});

// Endpoint untuk frontend mengambil daftar semua akun
app.get('/api/accounts', (req, res) => {
    const result = [];
    const now = Date.now();

    for (const [_, account] of accounts.entries()) {
        const timeDiffSeconds = Math.floor((now - account.lastSeen) / 1000);
        // Jika update kurang dari 5 menit yang lalu, status ONLINE
        const isOnline = timeDiffSeconds < 300;

        result.push({
            ...account,
            isOnline,
            lastSeenAgo: timeDiffSeconds
        });
    }

    // Urutkan akun: yang online di atas
    result.sort((a, b) => (b.isOnline ? 1 : 0) - (a.isOnline ? 1 : 0));
    res.json(result);
});

// Endpoint untuk frontend mengambil log telur yang baru didapat
app.get('/api/steal-events', (req, res) => {
    res.json(stealEvents);
});

app.listen(PORT, () => {
    console.log(`=======================================================`);
    console.log(`🚀 Steal An Egg - Web Joki Monitoring`);
    console.log(`🌐 Dashboard URL: http://localhost:${PORT}/monitoringjoki`);
    console.log(`🔑 Akses PIN   : ${ACCESS_PIN}`);
    console.log(`📡 Update API  : http://localhost:${PORT}/api/update`);
    console.log(`📡 Steal API   : http://localhost:${PORT}/api/steal-event`);
    console.log(`=======================================================`);
});
