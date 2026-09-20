const fs = require('fs');
const path = require('path');

// Helper generator nama variabel acak ala hacker / obfuscator
function randomVarName() {
    const chars = 'lI1O0';
    let name = '_0x' + Math.random().toString(16).substring(2, 6);
    for (let i = 0; i < 4; i++) {
        name += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return name;
}

function obfuscateLua(sourceCode) {
    const buffer = Buffer.from(sourceCode, 'utf8');
    const seed = Math.floor(Math.random() * 200) + 25; // 25 - 225
    const step = Math.floor(Math.random() * 50) + 11;  // 11 - 60

    // Enkripsi byte dengan Rolling-XOR Cipher
    const encryptedBytes = [];
    for (let i = 0; i < buffer.length; i++) {
        const key = (seed + ((i * step) % 127)) & 0xFF;
        const enc = (buffer[i] ^ key) & 0xFF;
        encryptedBytes.push(enc);
    }

    // Variabel acak untuk runtime deobfuscator
    const vTable = randomVarName();
    const vResult = randomVarName();
    const vLen = randomVarName();
    const vKey = randomVarName();
    const vByte = randomVarName();
    const vChar = randomVarName();
    const vConcat = randomVarName();
    const vBxor = randomVarName();
    const vLoader = randomVarName();
    const vRunner = randomVarName();

    // Format array angka terenkripsi
    const byteString = encryptedBytes.join(',');

    // Template VM / Loader Lua yang akan dieksekusi di Roblox Luau
    const protectedLua = `--[[
    =======================================================
    🔒 SysHub Premium Guard - Protected Lua Bytecode
    Protected At: ${new Date().toISOString()}
    Redistribution or modification without license is prohibited.
    =======================================================
]]
return (function()
    local ${vBxor} = bit32 and bit32.bxor or (function(a, b)
        local p, c = 1, 0
        while a > 0 and b > 0 do
            local ra, rb = a % 2, b % 2
            if ra ~= rb then c = c + p end
            a, b, p = (a - ra) / 2, (b - rb) / 2, p * 2
        end
        if a < b then a = b end
        while a > 0 do
            local ra = a % 2
            if ra > 0 then c = c + p end
            a, p = (a - ra) / 2, p * 2
        end
        return c
    end)
    local ${vChar} = string.char
    local ${vConcat} = table.concat
    local ${vTable} = {${byteString}}
    local ${vResult} = {}
    local ${vLen} = #${vTable}

    for i = 1, ${vLen} do
        local ${vKey} = (${seed} + (((i - 1) * ${step}) % 127)) % 256
        local ${vByte} = ${vBxor}(${vTable}[i], ${vKey})
        ${vResult}[i] = ${vChar}(${vByte})
    end

    local ${vLoader} = assert(loadstring or load)
    local ${vRunner} = ${vLoader}(${vConcat}(${vResult}))
    return ${vRunner}()
end)();
`;

    return protectedLua;
}

// CLI Runner
const inputFile = process.argv[2] || 'steal_an_egg.lua';
const outputFile = process.argv[3] || 'steal_an_egg_protected.lua';

const inputPath = path.resolve(__dirname, inputFile);
const outputPath = path.resolve(__dirname, outputFile);

if (!fs.existsSync(inputPath)) {
    console.error(`[Error] File "${inputFile}" tidak ditemukan!`);
    process.exit(1);
}

const rawCode = fs.readFileSync(inputPath, 'utf8');
console.log(`[Packer] Mengenkripsi "${inputFile}" (${rawCode.length} bytes)...`);

const obfuscated = obfuscateLua(rawCode);
fs.writeFileSync(outputPath, obfuscated, 'utf8');

console.log(`[Sukses] File berhasil di-obfuscate ke "${outputFile}"! (${obfuscated.length} bytes)`);
console.log(`[Info] Kode asli aman dan tidak bisa dibaca oleh user/orang lain.`);
