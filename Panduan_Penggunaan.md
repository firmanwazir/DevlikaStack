# ⚡ Panduan Penggunaan DevlikaStack v2.2

Panduan lengkap cara menggunakan **DevlikaStack** — aplikasi server lokal portabel berbasis Flutter Desktop untuk pengembangan web di Windows.

---

## 🚀 Cara Menjalankan

### Pertama Kali (Portable)

1. Unduh file `DevlikaStack-v2.2-windows-x64.zip` dari [Halaman Release GitHub](https://github.com/firmanwazir/DevlikaStack/releases/tag/v2.2).
2. Ekstrak ke lokasi mana saja (misalnya `D:\DevlikaStack-Portable\`).
3. Klik dua kali file **`DevlikaStack.exe`**.
4. Aplikasi akan otomatis meminta izin **Administrator** (diperlukan untuk menulis file `hosts` Windows dan menjalankan server di port 80).

> **Catatan**: Tidak perlu install apa pun. Cukup ekstrak dan jalankan. Semua data dan konfigurasi tersimpan di folder `bin/` dan `storage/`.

---

## 📱 Halaman & Navigasi Sidebar

Berikut semua halaman dan fitur yang tersedia di DevlikaStack:

### 1. Dashboard (Halaman Utama)
- Menampilkan **kartu status** Web Server dan MariaDB (hijau = aktif, abu-abu = mati).
- **Toggle ON/OFF** untuk Web Server dan MariaDB dengan satu klik.
- Pilihan **engine Web Server** (Native HTTP, Nginx, Apache) langsung dari dashboard.
- Daftar ringkas **website lokal** yang terdaftar beserta domain-nya.
- Chip port menunjukkan port layanan yang sedang aktif.

### 2. Pengaturan Port Bebas Konflik (Anti-Bentrok XAMPP)
Jika komputer Anda sudah terpasang software web server lain seperti **XAMPP, IIS, atau WampServer**, Anda tidak perlu mematikan software tersebut.
- Klik tombol **⚙️ Port Settings** di Header Bar atas.
- **Port Web Server**: Ganti dari port default `80` ke `8080` atau `8000`.
- **Port MariaDB / MySQL**: Ganti dari port default `3306` ke `3307` atau `3308`.
- Fitur **Pengecek Port Otomatis** akan langsung memeriksa apakah port tersebut sedang dipakai aplikasi lain atau siap digunakan.
- Pengaturan port tersimpan secara permanen di konfigurasi aplikasi.

### 3. Virtual Hosts (Kelola Website Lokal)
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

### 4. Web Server (Pilih Engine HTTP)
- Ganti engine antara **Native HTTP**, **Nginx 1.26**, dan **Apache HTTPD 2.4**.
- Menampilkan status engine aktif, port binding, dan proses PID.
- Perpindahan engine otomatis melepas port aktif sebelum mengaktifkan engine baru.

### 5. PHP Environment & Extension Switch Manager
Halaman PHP kini dibagi menjadi 3 tab yang lengkap dan modern:

#### Tab 1: Daftar Versi PHP
- Melihat daftar versi PHP terpasang (PHP 7.4, 8.1, 8.2, 8.3) beserta exact version-nya.
- Port FastCGI dedicated per versi:
  - PHP 7.4 → Port `9074`
  - PHP 8.1 → Port `9081`
  - PHP 8.2 → Port `9082`
  - PHP 8.3 → Port `9083`

#### Tab 2: Kelola Ekstensi (Visual Switch Manager)
- **Switch ON/OFF Visual**: Aktifkan atau nonaktifkan ekstensi PHP (`curl`, `intl`, `pdo_mysql`, `mbstring`, `gd`, `zip`, `fileinfo`, `sodium`, dll) cukup dengan toggle switch tanpa perlu mengedit file `php.ini` secara manual.
- **FastCGI Hot-Reload Instan**: Setiap toggle langsung memperbarui konfigurasi PHP dan memuat ulang FastCGI worker pool otomatis tanpa restart web server.
- **Preset Cepat 1-Klik**:
  - 🚀 **Laravel**: Mengaktifkan seluruh ekstensi wajib Laravel (`pdo_mysql`, `openssl`, `mbstring`, `curl`, `intl`, `gd`, `fileinfo`, `zip`, `opcache`).
  - 🌐 **WordPress**: Mengaktifkan seluruh ekstensi WordPress (`mysqli`, `curl`, `gd`, `intl`, `mbstring`, `openssl`, `zip`, `exif`, `fileinfo`, `opcache`).
  - ⚡ **Minimal**: Konfigurasi dasar yang ringan (`pdo_mysql`, `mbstring`, `openssl`, `curl`).
- **Pencarian 0ms (In-Memory)**: Mencari ekstensi secara instan tanpa micro-stutter atau lag disk I/O.
- **Sortir Lengkap**:
  - **Aktif di Atas** *(Default)*: Ekstensi aktif otomatis terkumpul di bagian paling atas.
  - **Nama (A - Z)** & **Nama (Z - A)**: Pengurutan alfabetis.
  - **Kategori**: Pengelompokan berdasarkan jenis ekstensi.
- **Filter Status**: Tampilkan *Semua Status*, *Hanya Aktif*, atau *Hanya Nonaktif*.
- **Kategori Responsif (`Wrap`)**: Chips kategori rapi dengan ikon unik, warna tema (Database: Sky Blue, Web: Teal, Media: Amber, Security: Emerald, Framework: Purple, Performance: Orange), serta badge rasio aktif (contoh: `Database 3/6`).
- **Otomasi Zend OPcache & GD**: Otomatis menyinkronkan direktif `zend_extension=opcache` dan membersihkan perbedaan penamaan `extension=gd2` vs `extension=gd` antara PHP 7.4 dan PHP 8.x.

#### Tab 3: Editor php.ini (Visual Form)
- Ubah direktif konfigurasi utama dengan form visual yang aman:
  - `memory_limit` (misal `512M`)
  - `upload_max_filesize` (misal `128M`)
  - `post_max_size` (misal `128M`)
  - `max_execution_time` (misal `300`)
  - `max_input_vars` (misal `5000`)
  - `date.timezone` (misal `Asia/Jakarta`)
  - `display_errors` (`On` untuk development, `Off` untuk production)
  - `cgi.fix_pathinfo` (`1` untuk framework routing)

### 6. MariaDB Server
- Status koneksi database (Port default 3306, user `root`, tanpa password).
- Parameter binding: `127.0.0.1` dan `::1` (dual-stack).
- Informasi versi MariaDB dan lokasi data directory.
- Optimasi bawaan: `skip-name-resolve`, query cache 64MB.

### 7. SQL Importer (Turbo Import)
- Import file `.sql` dump besar (ratusan MB) langsung ke database MariaDB.
- Menggunakan metode **chunked transaction buffering** untuk mencegah kehabisan memori.
- Pilih database tujuan, pilih file SQL, lalu klik "Import".
- Progress bar real-time menampilkan persen dan kecepatan import.

### 8. phpMyAdmin
- Akses phpMyAdmin via browser pada `http://localhost:<port>/__phpmyadmin`.
- Tombol **"Buka phpMyAdmin"** langsung membuka browser dan auto-login ke MariaDB.
- Kelola tabel, jalankan query, export/import database semuanya via antarmuka web.

### 9. Cloudflare Tunnel (Online Preview)
Fitur ini memungkinkan Anda membagikan website lokal ke internet **tanpa IP publik, tanpa port forwarding, dan tanpa akun Cloudflare**.

**Cara Menggunakan:**
1. Buka halaman **Cloudflare Tunnel** di sidebar.
2. Pilih mode: **Virtual Host** (pilih domain dari dropdown) atau **Port Kustom** (masukkan nomor port).
3. Klik tombol **"Mulai Tunnel Preview"**.
4. Tunggu beberapa detik hingga status berubah menjadi **ONLINE**.
5. Anda akan mendapat link publik seperti `https://abc-xyz-123.trycloudflare.com`.
6. **Salin** link tersebut dan kirim ke klien — mereka bisa membukanya di browser smartphone atau laptop mana pun.

**Fitur Unggulan Tunnel:**
- ✅ **HTTPS Resmi Valid** — Sertifikat SSL resmi dari Cloudflare Anycast, tanpa peringatan keamanan di browser klien.
- ✅ **Gratis & Unlimited** — Tidak ada batasan bandwidth.
- ✅ **Tanpa Akun** — Langsung aktif tanpa registrasi atau auth token.
- ✅ **Auto-Reconnect** — Jika tunnel terputus sementara, DevlikaStack otomatis menyambung ulang dengan exponential backoff (maksimal 5 percobaan).
- ✅ **Health Check** — Pengecekan otomatis setiap 30 detik untuk memastikan proses tunnel tetap aktif.
- ✅ **Auto-Download** — Binary `cloudflared.exe` (~55 MB) diunduh otomatis saat pertama kali digunakan.

### 10. Pusat Komponen (Environment)
- Melihat status instalasi setiap komponen: PHP, MariaDB, phpMyAdmin, Nginx, Apache.
- Tombol **"Install Semua Komponen Sekaligus"** — download dan setup semua runtime dengan 1 klik.
- Atau install **per-komponen** dengan progress bar real-time.

### 11. Log Aktivitas (Live Terminal)
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
- Cukup aktifkan preset **Laravel** di tab Kelola Ekstensi PHP.
- OPcache aktif untuk performa optimal.
- URL rewrite otomatis (`/login`, `/api/v1/data`, dll) tanpa konfigurasi tambahan.
- Header `Authorization: Bearer <token>` diteruskan untuk Laravel Sanctum / Passport / JWT.
- Deteksi otomatis folder `public/` sebagai DocumentRoot.

### CodeIgniter 4
- Ekstensi wajib aktif: `intl`, `mbstring`, `mysqli`, `curl`, `json`.
- Deteksi otomatis folder `public/` untuk CI4.

### WordPress
- Cukup aktifkan preset **WordPress** di tab Kelola Ekstensi PHP.
- URL rewrite untuk permalink cantik (`/2024/01/my-post/`).

---

## 📂 Struktur Folder Portabel

```text
DevlikaStack-Portable/
├── DevlikaStack.exe                 <-- Klik 2x untuk menjalankan (auto-admin)
├── flutter_windows.dll              <-- Flutter Runtime
├── *.dll                            <-- Plugin libraries
├── data/                            <-- Asset internal (app.so, shader, font)
└── bin/                             <-- Semua komponen server portabel
    ├── php/                         <-- Multi-versi PHP (7.4, 8.1, 8.2, 8.3)
    ├── mariadb/                     <-- MariaDB Daemon & Data
    ├── nginx/                       <-- Nginx 1.26 Engine
    ├── apache/                      <-- Apache HTTPD 2.4 Engine
    ├── tools/
    │   ├── phpmyadmin/              <-- phpMyAdmin Full Version
    │   └── cloudflared.exe          <-- Cloudflare Tunnel (auto-download)
    ├── storage/
    │   ├── mariadb/                 <-- File database MySQL pribadi
    │   ├── sites.json               <-- Daftar Virtual Hosts
    │   └── settings.json            <-- Pengaturan aplikasi & port
    └── demo-site/                   <-- Website contoh demo.local
```

> **Tips Portabilitas**: Folder `DevlikaStack-Portable` ini bisa langsung di-copy ke flashdisk atau PC lain tanpa perlu install apapun. Semua data dan konfigurasi ikut terbawa.

---

## ❓ FAQ (Pertanyaan Umum)

**Q: Apakah saya bisa menjalankan DevlikaStack bersamaan dengan XAMPP?**  
A: **Bisa!** DevlikaStack v2.2 memiliki fitur *Custom Port Conflict Management*. Cukup buka pengaturan port di header atas dan ubah port Web Server ke `8080` dan MariaDB ke `3307`. Keduanya bisa berjalan berdampingan tanpa saling bertabrakan.

**Q: Apakah data database saya aman jika aplikasi di-update?**  
A: **Sangat aman.** Database tersimpan di `bin/storage/mariadb/`. Saat mengupdate versi baru, Anda hanya perlu mengganti file executable dan folder `data/` hasil ekstrak rilis, tanpa menyentuh folder `bin/` yang berisi database Anda.

**Q: Mengapa butuh akses Administrator saat start?**  
A: Untuk dua hal: (1) Menulis ke file `hosts` Windows agar domain lokal bisa diakses di browser, dan (2) Membuka binding socket port 80 pada Windows.

**Q: Bagaimana cara memperbarui ekstensi PHP?**  
A: Cukup buka halaman **PHP Environment** → tab **Kelola Ekstensi**, klik toggle switch pada ekstensi yang ingin diaktifkan/dinonaktifkan. FastCGI akan langsung hot-reload otomatis tanpa perlu restart aplikasi.
