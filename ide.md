# DevlikaStack - Peta Rencana & Ide Pengembangan Fitur (Roadmap)

Dokumen ini merangkum seluruh ide fitur inovatif dan rencana pengembangan masa depan untuk **DevlikaStack**, dirancang untuk menjadikannya lingkungan web server lokal modern (*local development environment*) terbaik dan paling ramah developer di Windows, melampaui batasan XAMPP dan setara dengan standar Laravel Herd / LocalWP / ServBay.

---

## 📌 Status Fitur Saat Ini (Versi 2.1)
- ⚡ **Startup Instan (Sub-Detik)**: Tanpa *loading freeze*, *lazy-mounted tabs*, dan *fast-boot architecture*.
- 🎨 **Desain Obsidian & Dark Zinc**: UI profesional bergaya *Linear / Raycast / Datadog* tanpa tampilan *AI-slop*.
- 🐘 **Multi-PHP Engine Portable**: PHP 7.4, 8.1, 8.2, dan 8.3 dengan FastCGI pool paralel terisolasi.
- 🌐 **Multi-Web Server Engine**: Devlika Native HTTP, Nginx 1.26 Portable, dan Apache HTTPD 2.4.
- 🔌 **Dynamic Port & Coexistence XAMPP/IIS**:
  - Port HTTP (80 / 8080 / 8000) dan HTTPS (443 / 8443).
  - Port MariaDB (3306 / 3307).
  - *Pre-flight conflict detector* yang mendeteksi proses pengunci port secara real-time.
- 🏠 **Virtual Host & Otomatisasi SSL**: Setup domain `.test` / `.local` dengan sertifikat CA lokal instan.
- 🐬 **MariaDB 11.x Turbo**: Konfigurasi `my.ini` teroptimasi untuk performa RAM dan storage Windows NTFS.
- 🚀 **Turbo DB Importer**: Impor file database SQL multi-gigabyte dengan teknik *stream chunking* tanpa time-out.
- 🌍 **Cloudflare Quick Tunnel**: Ekspos website lokal ke internet publik dalam 1 klik dengan auto-reconnect.
- 🗄️ **phpMyAdmin 5.x**: Manajemen database visual berbasis web terintegrasi.

---

## 💡 Daftar Ide Fitur Baru (Future Feature Roadmap)

### 1. 🧩 Visual PHP Extensions & `php.ini` Switch Manager [✅ SELESAI / IMPLEMENTED]
- **Status**: **Rilis pada Versi 2.2** 🚀
- **Deskripsi**: Mengelola ekstensi PHP secara visual menggunakan saklar switch (ON / OFF) langsung dari tab `Ekstensi PHP (Switch Manager)`.
- **Fitur yang Diimplementasikan**:
  - **Katalog Ekstensi Lengkap**: Mendukung 24+ ekstensi standar industri (`pdo_mysql`, `mysqli`, `pdo_sqlite`, `sqlite3`, `pdo_pgsql`, `pgsql`, `curl`, `soap`, `sockets`, `ldap`, `gd`, `zip`, `fileinfo`, `exif`, `bz2`, `openssl`, `sodium`, `intl`, `mbstring`, `bcmath`, `gmp`, `tidy`, `opcache`, `xdebug`) ditambah deteksi otomatis file `.dll` kustom di folder `ext/`.
  - **Batch Presets Instan**:
    - 🚀 **Preset Laravel**: Mengaktifkan seluruh ekstensi wajib Laravel & Filament (`curl, intl, gd, fileinfo, mbstring, openssl, pdo_mysql, zip, sodium, pdo_sqlite, sqlite3, bcmath, opcache`).
    - 🌐 **Preset WordPress**: Mengaktifkan ekstensi wajib WordPress (`curl, gd, intl, mbstring, mysqli, openssl, zip, exif, fileinfo, opcache`).
    - ⚡ **Preset Minimal**: Ekstensi inti hemat RAM (`pdo_mysql, mbstring, openssl, curl`).
  - **Pencarian & Filter Kategori**: Filter instan berdasarkan kategori (*Database, Web & API, Media & File, Security & Crypto, Framework & Text, Performance & Debug, Ekstensi Ekstra*) dan kolom pencarian kata kunci.
  - **Multi-Version Switching**: Konfigurasi independen per versi PHP terpasang (PHP 7.4, 8.1, 8.2, 8.3) dengan penanganan otomatis aturan khusus (seperti `gd2` pada PHP 7.4 vs `gd` pada PHP 8.x).
  - **Zero-Downtime FastCGI Hot-Reload**: Saat saklar ekstensi digeser atau preset diklik, `php.ini` diperbarui seketika dan worker pool FastCGI otomatis di-reload tanpa perlu restart aplikasi atau web server.
  - **Validasi Ketersediaan Binary**: Indikator status apakah file binary `.dll` ada di folder disk `ext/` untuk mencegah crash saat FastCGI dijalankan.

---

### 2. 📬 Local Mailbox / Fake SMTP Sandbox (Mailpit Integration)
- **Deskripsi**: Server penampung email lokal terisolasi (*fake SMTP server*) dengan Web Dashboard visual bawaan.
- **Masalah yang Diatasi**: Menguji pengiriman email (registrasi akun, kirim OTP, reset password, invoice) di lingkungan lokal Windows biasanya sangat menyulitkan karena XAMPP membutuhkan konfigurasi `sendmail.ini` dan akun email asli yang rawan diblokir.
- **Fitur Utama**:
  - Binary portable ringan **Mailpit** (single-binary Go, < 15MB, konsumsi RAM < 20MB).
  - Port SMTP lokal `1025`: PHP `mail()`, Laravel SMTP, WordPress, dan PHPMailer langsung mengarah ke `127.0.0.1:1025` tanpa password.
  - Web UI Email Viewer di port `8025` (`http://localhost:8025`):
    - Tampilan inbox modern untuk membaca email HTML, plain text, dan attachment.
    - Dilengkapi fitur *Mobile/Desktop preview* dan pengujian link di dalam email.
    - Tidak ada risiko email terkirim ke alamat email nyata pelanggan.

---

### 3. 🚀 1-Click Quick Site Creator (Framework & CMS Starter)
- **Deskripsi**: Generator pembuatan project baru secara instan dalam 1 klik untuk framework dan CMS populer.
- **Masalah yang Diatasi**: Menyiapkan project baru biasanya memakan waktu 10-15 menit (buka terminal, jalankan composer create-project, buat database di phpMyAdmin, edit `.env`, daftarkan Virtual Host, install SSL).
- **Template yang Didukung**:
  - **WordPress**: Mengunduh core WordPress terbaru, konfigurasi `wp-config.php`, buat database, siap install.
  - **Laravel**: Menyiapkan struktur Laravel, generate `.env`, buat database MariaDB, `APP_KEY`, siap pakai.
  - **CodeIgniter 4**: Menyiapkan boilerplate CI4 dengan `public/` routing terkonfigurasi.
  - **Blank PHP / HTML**: Template bersih untuk koding dari nol.
- **Alur Kerja**:
  1. User klik **"+ Buat Project Baru"**.
  2. Masukkan nama project (misal: `toko-online`).
  3. DevlikaStack otomatis:
     - Membuat folder di `www/toko-online`.
     - Mengekstrak template.
     - Membuat database di MariaDB (`db_toko_online`).
     - Mendaftarkan Virtual Host (`toko-online.test`) + SSL certificate.
     - Membuka browser langsung ke project baru.

---

### 4. ⚡ Redis Portable Server for Windows (Cache & Queue Engine)
- **Deskripsi**: Server basis data in-memory Redis portable untuk caching dan asynchronous background queue.
- **Masalah yang Diatasi**: Redis resmi tidak mendukung Windows secara langsung, memaksa developer menggunakan Docker atau WSL2 yang memakan RAM besar (1-2 GB).
- **Fitur Utama**:
  - Binary Redis Windows Portable (Port `6379`).
  - Toggle Start / Stop di Dashboard DevlikaStack.
  - Konsumsi memori sangat minim (< 15MB RAM).
  - Sangat bermanfaat untuk project Laravel (Cache, Session, Horizon/Queue) dan WordPress (Redis Object Cache).

---

### 5. 💻 Terminal Pintar per-Project (Context-Aware CLI)
- **Deskripsi**: Tombol terminal khusus pada setiap kartu Virtual Host yang otomatis mengkonfigurasi environment sesuai kebutuhan project tersebut.
- **Fitur Utama**:
  - Tombol **"Buka Terminal"** di menu Virtual Hosts.
  - Saat diklik, membuka CMD / PowerShell langsung di direktori root project.
  - Variabel `PATH` di-inject secara dinamis untuk sesi tersebut:
    - Jika project memakai **PHP 7.4**, perintah `php -v` otomatis mengeksekusi PHP 7.4.
    - Jika project memakai **PHP 8.2**, perintah `php -v` otomatis mengeksekusi PHP 8.2.
    - Perintah `composer`, `mysql`, dan tool CLI bawaan langsung dikenali tanpa perlu menyentuh System Environment Variables Windows.

---

### 6. 🗂️ Project Snapshot & Backup (1-Click Export / Import)
- **Deskripsi**: Utilitas untuk mencadangkan dan memindahkan project web antar komputer dengan sekali klik.
- **Fitur Utama**:
  - **Export**: Mengemas seluruh file kodingan website + dump file SQL database MariaDB menjadi 1 file arsip `.zip` atau `.devlika`.
  - **Import**: Mengekstrak arsip di laptop lain, otomatis merestore database ke MariaDB, dan mendaftarkan Virtual Host-nya kembali.
  - Sangat praktis untuk kolaborasi tim, backup mingguan, atau migrasi laptop kerja.

---

### 7. 📑 Adminer Portable (Alternatif phpMyAdmin Ringan)
- **Deskripsi**: Pengelola database alternatif phpMyAdmin yang berukuran super mini.
- **Fitur Utama**:
  - Berupa 1 file script PHP tunggal (~450 KB).
  - Membuka instan dalam 0.1 detik.
  - Mendukung MariaDB/MySQL dan SQLite.
  - Pilihan ideal untuk komputer dengan spesifikasi rendah atau developer yang menginginkan GUI database super cepat.

---

### 8. ⏰ Local Cron / Task Scheduler Simulator
- **Deskripsi**: Emulator cron job Linux untuk menjalankan scheduled tasks di Windows.
- **Masalah yang Diatasi**: Framework seperti Laravel (`php artisan schedule:run`) atau WordPress (`wp-cron.php`) membutuhkan Cron Job berkala yang sulit disetup di Windows Task Scheduler.
- **Fitur Utama**:
  - Scheduler bawaan di DevlikaStack yang mengeksekusi perintah command setiap 1 menit atau interval yang ditentukan.
  - Konsol log eksekusi cron langsung di tab Logs.

---

## 📊 Matriks Perbandingan & Prioritas Implementasi

| No | Fitur | Kompleksitas | Dampak Pengguna | Rekomendasi Prioritas |
|---|---|---|---|---|
| 1 | **Visual PHP Extensions & `php.ini` Manager** | Sedang | ⭐⭐⭐⭐⭐ Sangat Tinggi | **Prioritas 1 (Segera)** |
| 2 | **Local Mailbox (Mailpit / Fake SMTP)** | Rendah - Sedang | ⭐⭐⭐⭐⭐ Sangat Tinggi | **Prioritas 1 (Segera)** |
| 3 | **Quick Site Creator (WordPress/Laravel)** | Sedang | ⭐⭐⭐⭐⭐ Sangat Tinggi | **Prioritas 2** |
| 4 | **Terminal Pintar per-Project** | Rendah | ⭐⭐⭐⭐ Tinggi | **Prioritas 2** |
| 5 | **Redis Portable for Windows** | Rendah | ⭐⭐⭐⭐ Tinggi | **Prioritas 3** |
| 6 | **Adminer Portable DB Browser** | Sangat Rendah | ⭐⭐⭐ Sedang | **Prioritas 3** |
| 7 | **Project Snapshot & Backup (Zip)** | Sedang | ⭐⭐⭐⭐ Tinggi | **Prioritas 4** |
| 8 | **Local Cron / Task Scheduler** | Sedang | ⭐⭐⭐ Sedang | **Prioritas 4** |

---

## 🛡️ Prinsip & Integritas Arsitektur
1. **100% Portable**: Tidak boleh memerlukan instalasi ke registry Windows atau folder `Program Files`. Seluruh binary dan data tetap berada di dalam folder portable.
2. **Keamanan Database User**: Folder `mariadb/data` dan database yang sudah dibuat pengguna adalah aset berharga dan tidak boleh tersentuh atau terhapus saat pembaruan fitur.
3. **Performa Ringan**: Setiap fitur baru tidak boleh memperlambat waktu buka (*startup time*) aplikasi utama DevlikaStack.
