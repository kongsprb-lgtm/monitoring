const express = require('express');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Menyimpan data akun di memory
const accounts = new Map();

// Endpoint untuk menerima statistik dari script executor
app.post('/api/update', (req, res) => {
    const { username, displayName, userId, uptime, ping, stats } = req.body;

    if (!username) {
        return res.status(400).json({ error: 'Username diperlukan' });
    }

    accounts.set(username, {
        username,
        displayName: displayName || username,
        userId: userId || 0,
        uptime: uptime || 'N/A',
        ping: ping || 'N/A',
        stats: Array.isArray(stats) ? stats : [],
        lastSeen: Date.now()
    });

    console.log(`[Update] Diterima dari ${username} (${displayName})`);
    res.json({ success: true });
});

// Endpoint untuk frontend mengambil daftar akun
app.get('/api/accounts', (req, res) => {
    const result = [];
    const now = Date.now();

    for (const [_, account] of accounts.entries()) {
        const timeDiffSeconds = Math.floor((now - account.lastSeen) / 1000);
        // Jika update kurang dari 10 menit yang lalu, status ONLINE
        const isOnline = timeDiffSeconds < 600;

        result.push({
            ...account,
            isOnline,
            lastSeenAgo: timeDiffSeconds
        });
    }

    res.json(result);
});

app.listen(PORT, () => {
    console.log(`=============================================`);
    console.log(`🚀 Monitoring Server berjalan di http://localhost:${PORT}`);
    console.log(`Endpoint untuk executor: http://localhost:${PORT}/api/update`);
    console.log(`=============================================`);
});
