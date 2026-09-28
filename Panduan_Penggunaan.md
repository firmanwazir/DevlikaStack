# ⚡ Panduan Penggunaan DevlikaStack

Panduan lengkap cara menggunakan **DevlikaStack** — aplikasi server lokal portabel berbasis Flutter Desktop untuk pengembangan web di Windows.

---

## 🚀 Cara Menjalankan

### Pertama Kali (Portable)

1. Unduh file `DevlikaStack-v2.1-windows-x64.zip` dari [halaman Release GitHub](https://github.com/firmanwazir/DevlikaStack/releases).
2. Ekstrak ke lokasi mana saja (misalnya `D:\DevlikaStack-Portable\`).
3. Klik dua kali file **`DevlikaStack.exe`**.
4. Aplikasi akan otomatis meminta izin **Administrator** (diperlukan untuk menulis file `hosts` Windows dan menjalankan server di port 80).

> **Catatan**: Tidak perlu install apa pun. Cukup ekstrak dan jalankan. Semua data dan konfigurasi tersimpan di folder `bin/`.

---

## 📱 Halaman & Navigasi Sidebar

Berikut semua halaman yang tersedia di sidebar kiri aplikasi:

### 1. Dashboard (Halaman Utama)
- Menampilkan **kartu status** Web Server dan MariaDB (hijau = aktif, abu-abu = mati).
- **Toggle ON/OFF** untuk Web Server dan MariaDB dengan satu klik.
- Pilihan **engine Web Server** (Native HTTP, Nginx, Apache) langsung dari dashboard.
- Daftar ringkas **website lokal** yang terdaftar beserta domain-nya.
- Port chip menunjukkan port layanan yang sedang aktif.

### 2. Virtual Hosts (Kelola Website Lokal)
- Tabel daftar semua domain lokal (contoh: `demo.local`, `siakad.id`).
- **Tambah Domain Baru**: Klik tombol "Tambah Host" → isi nama domain, pilih versi PHP, dan tentukan folder DocumentRoot.
- Kolom **Aksi** untuk setiap host:
  - 🌐 **Buka di Browser** — Langsung buka domain di browser default.
  - 📂 **Buka Folder** — Buka folder DocumentRoot di File Explorer.
  - ☁️ **Online Tunnel** — Bagikan host ini ke internet via Cloudflare Tunnel.
  - ✏️ **Edit** — Ubah konfigurasi domain.
  - 🗑️ **Hapus** — Hapus domain dari daftar.
- Deteksi otomatis folder `public/` untuk **Laravel** dan `public_html/` untuk **CodeIgniter**.
- **Reverse Proxy**: Arahkan domain lokal ke backend Node.js, Go, Python, dll yang berjalan di port kustom.
- Sinkronisasi otomatis ke file `C:\Windows\System32\drivers\etc\hosts` dengan mapping IPv4 dan IPv6.

### 3. Web Server (Pilih Engine HTTP)
- Ganti engine antara **Native HTTP**, **Nginx 1.26**, dan **Apache HTTPD 2.4**.
- Menampilkan status engine aktif, port binding, dan proses PID.
- Perpindahan engine otomatis melepas port 80 sebelum mengaktifkan engine baru.

### 4. PHP Environment
- Informasi lengkap versi PHP yang terinstal (PHP 7.4, 8.1, 8.2, 8.3).
- Daftar **ekstensi PHP aktif** per versi (intl, mbstring, pdo_mysql, curl, gd, zip, dll).
- Path ke file `php.ini` dan konfigurasi penting:
  - `memory_limit = 512M`
  - `upload_max_filesize = 128M`
  - `max_execution_time = 300`
  - `OPcache = Enabled`
- Port FastCGI per versi:
  - PHP 7.4 → Port `9074`
  - PHP 8.1 → Port `9081`
  - PHP 8.2 → Port `9082`
  - PHP 8.3 → Port `9083`

### 5. MariaDB Server
- Status koneksi database (Port 3306, user `root`, tanpa password).
- Parameter binding: `127.0.0.1` dan `::1` (dual-stack).
- Informasi versi MariaDB dan lokasi data directory.
- Optimasi bawaan: `skip-name-resolve`, query cache 64MB.

### 6. SQL Importer (Turbo Import)
- Import file `.sql` dump besar (ratusan MB) langsung ke database MariaDB.
- Menggunakan metode **chunked transaction buffering** untuk mencegah kehabisan memori.
- Pilih database tujuan, pilih file SQL, lalu klik "Import".
- Progress bar real-time menampilkan persen dan kecepatan import.

### 7. phpMyAdmin
- Akses phpMyAdmin via `http://localhost/__phpmyadmin`.
- Tombol **"Buka phpMyAdmin"** langsung membuka browser dan auto-login ke MariaDB.
- Kelola tabel, jalankan query, export/import database semuanya via antarmuka web.

### 8. Cloudflare Tunnel (Online Preview)
Fitur ini memungkinkan Anda membagikan website lokal ke internet **tanpa IP publik, tanpa port forwarding, dan tanpa akun Cloudflare**.

**Cara Menggunakan:**
1. Buka halaman **Cloudflare Tunnel** di sidebar.
2. Pilih mode: **Virtual Host** (pilih domain dari dropdown) atau **Port Kustom** (masukkan nomor port).
3. Klik tombol **"Mulai Tunnel Preview"**.
4. Tunggu beberapa detik hingga status berubah menjadi **ONLINE**.
5. Anda akan mendapat link publik seperti `https://abc-xyz-123.trycloudflare.com`.
6. **Salin** link tersebut dan kirim ke klien — mereka bisa membukanya di browser mana pun di smartphone atau laptop.

**Fitur Unggulan Tunnel:**
- ✅ **HTTPS Resmi Valid** — Sertifikat SSL resmi dari Cloudflare, tanpa peringatan keamanan di browser klien.
- ✅ **Gratis & Unlimited** — Tidak ada batasan bandwidth seperti di ngrok versi gratis.
- ✅ **Tanpa Akun** — Langsung aktif tanpa registrasi atau auth token.
- ✅ **Auto-Reconnect** — Jika tunnel mati secara tiba-tiba, DevlikaStack otomatis menyambung ulang dengan jeda bertahap (3→6→12→24→48 detik), maksimal 5 percobaan. Fitur ini bisa diaktifkan/nonaktifkan via toggle switch.
- ✅ **Health Check** — Pengecekan otomatis setiap 30 detik untuk memastikan proses tunnel masih berjalan.
- ✅ **Auto-Download** — Binary `cloudflared.exe` (~55 MB) diunduh otomatis saat pertama kali digunakan.

**Cara Cepat dari Tabel Virtual Host:**
- Di halaman **Virtual Hosts**, setiap baris domain memiliki tombol ☁️ **Tunnel** untuk langsung membuka dialog tunnel tanpa perlu berpindah halaman.

### 9. Pusat Komponen (Environment)
- Melihat status instalasi setiap komponen: PHP, MariaDB, phpMyAdmin, Nginx, Apache.
- Tombol **"Install Semua Komponen Sekaligus"** — download dan setup semua runtime dengan 1 klik.
- Atau install **per-komponen** (PHP saja, MariaDB saja, dll) dengan progress bar real-time.
- Indikator hijau ✅ jika komponen sudah terinstal, amber ⚠️ jika belum.

### 10. Log Aktivitas (Live Terminal)
- Terminal log real-time menampilkan seluruh aktivitas server:
  - Request HTTP masuk (URL, method, status code, response time).
  - Query database dari phpMyAdmin atau aplikasi.
  - Output error PHP.
  - Status proses tunnel.
- Tombol **"Bersihkan Log"** untuk mengosongkan tampilan.

---

## ⚡ Dukungan Framework PHP Modern

DevlikaStack siap digunakan untuk framework populer:

### Laravel 9 / 10 / 11
- Semua ekstensi wajib aktif: `pdo_mysql`, `openssl`, `sodium`, `bcmath`, `fileinfo`, `gd`, `zip`, `exif`, `mbstring`, `tokenizer`, `xml`, `ctype`.
- OPcache aktif untuk performa optimal.
- URL rewrite otomatis (`/login`, `/api/v1/data`, dll) tanpa konfigurasi tambahan.
- Header `Authorization: Bearer <token>` diteruskan untuk Laravel Sanctum / Passport / JWT.
- Deteksi otomatis folder `public/` sebagai DocumentRoot.

### CodeIgniter 4
- Ekstensi wajib aktif: `intl`, `mbstring`, `mysqli`, `curl`, `json`.
- Deteksi otomatis folder `public/` untuk CI4.

### WordPress
- Ekstensi wajib aktif: `mysqli`, `gd`, `curl`, `xml`, `mbstring`, `zip`.
- URL rewrite untuk permalink cantik (`/2024/01/my-post/`).

---

## 📂 Struktur Folder Portabel

```text
DevlikaStack-Portable/
├── DevlikaStack.exe                 <-- Klik 2x untuk menjalankan (auto-admin)
├── flutter_windows.dll              <-- Flutter Runtime
├── *.dll                            <-- Plugin libraries
├── data/                            <-- Asset internal (shader, font, app.so)
└── bin/                             <-- Semua komponen server portabel
    ├── php/                         <-- Multi-versi PHP (7.4, 8.1, 8.2, 8.3)
    ├── mariadb/                     <-- MariaDB Daemon & Data
    ├── nginx/                       <-- Nginx 1.26 Engine
    ├── apache/                      <-- Apache HTTPD 2.4 Engine
    ├── tools/
    │   ├── phpmyadmin/              <-- phpMyAdmin Full Version
    │   └── cloudflared.exe          <-- Cloudflare Tunnel (auto-download)
    ├── storage/
    │   ├── mariadb/                 <-- File database MySQL
    │   ├── sites.json               <-- Daftar Virtual Hosts
    │   └── settings.json            <-- Pengaturan aplikasi
    └── demo-site/                   <-- Website contoh demo.local
```

> **Tips Portabilitas**: Folder `DevlikaStack-Portable` ini bisa langsung di-copy ke flashdisk atau PC lain tanpa perlu install apapun. Semua data dan konfigurasi ikut terbawa.

---

## ❓ FAQ (Pertanyaan Umum)

**Q: Apakah saya perlu install PHP, MySQL, atau web server secara terpisah?**
A: Tidak. Semua sudah dibundel di dalam folder `bin/`. Cukup klik `DevlikaStack.exe`.

**Q: Apakah data database saya tersimpan secara portabel?**
A: Ya. Database MariaDB tersimpan di `bin/storage/mariadb/`. Jika Anda copy folder DevlikaStack ke komputer lain, database ikut terbawa.

**Q: Mengapa butuh akses Administrator?**
A: Untuk dua hal: (1) Menulis ke file `hosts` Windows agar domain lokal bisa diakses di browser, dan (2) Menjalankan web server di port 80 yang memerlukan privilege admin.

**Q: Tunnel Cloudflare tiba-tiba mati, bagaimana?**
A: Jika fitur **Auto-Reconnect** aktif (default ON), DevlikaStack akan otomatis menyambung ulang. Jika gagal setelah 5 percobaan, Anda bisa klik manual "Mulai Tunnel Preview" lagi.

**Q: Apakah tunnel Cloudflare benar-benar gratis?**
A: Ya, Cloudflare Quick Tunnel 100% gratis tanpa batasan bandwidth. Tidak perlu akun atau auth token. URL berubah setiap kali tunnel dimulai ulang karena menggunakan mode Quick Tunnel (bukan Named Tunnel).

**Q: Bagaimana cara memperbarui DevlikaStack?**
A: Unduh versi terbaru dari [GitHub Releases](https://github.com/firmanwazir/DevlikaStack/releases), ekstrak, lalu copy file-file baru ke folder DevlikaStack Anda. **Jangan hapus folder `bin/`** — di sana tersimpan database dan konfigurasi Anda.
