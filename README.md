# DevlikaStack

Aplikasi desktop Windows (Flutter) untuk menjalankan dan mengelola web server lokal secara portabel tanpa instalasi sistem.

## Fungsi Aplikasi

### 1. Web Server Engine
- **Native HTTP Engine**: Web server internal di port 80 dan 443 dengan persistent Keep-Alive, in-memory cache untuk asset statis, dan parser aturan `.htaccess` (RewriteRule, RewriteCond, Header, php_value).
- **Pilihan Engine**: Mendukung pergantian engine web server antara Native HTTP Server, Nginx (1.26), atau Apache HTTPD (2.4) pada port 80 tanpa konflik socket.
- **SSL / HTTPS**: Pembuatan sertifikat SSL lokal otomatis untuk pengujian HTTPS pada port 443.

### 2. Multi-PHP & FastCGI Daemon
- Mendukung beberapa versi PHP aktif sekaligus (misalnya PHP 7.4, 8.1, 8.2, 8.3).
- Pemilihan versi PHP dapat diatur berbeda untuk masing-masing virtual host / website.
- Komunikasi PHP via daemon FastCGI (`php-cgi.exe`) dengan worker pool (`PHP_FCGI_CHILDREN`), menghindari overhead spawn process baru pada setiap HTTP request.
- Konfigurasi dual-stack loopback dan optimasi realpath cache per-versi PHP.

### 3. Database MariaDB & phpMyAdmin
- Service MariaDB lokal berjalan di port 3306 dengan binding dual-stack loopback (`127.0.0.1,::1`) dan parameter `--skip-name-resolve` untuk menghindari timeout pada koneksi `localhost`.
- Integrasi phpMyAdmin bawaan yang langsung terhubung ke service MariaDB lokal.
- Fitur Import Database untuk file `.sql` berukuran besar dengan pembagian chunk transaksi bertahap agar tidak memicu memory limit atau connection timeout.

### 4. Virtual Host & Domain Lokal
- Penambahan domain lokal kustom (contoh: `projek.local`, `siakad.test`).
- Sinkronisasi otomatis ke file Windows hosts (`C:\Windows\System32\drivers\etc\hosts`) memetakan entri IPv4 (`127.0.0.1`) dan IPv6 (`::1`).
- Deteksi otomatis document root folder proyek (`public/index.php` untuk Laravel, `public_html/index.php` untuk CodeIgniter atau arsitektur lama).
- Dukungan reverse proxy untuk mengarahkan domain lokal ke port aplikasi lain (Node.js, Go, Python).

### 5. Portabilitas & System Tray
- Berjalan mandiri (portabel): seluruh binary runtime, file database, dan konfigurasi tersimpan di dalam folder aplikasi tanpa mengubah registry Windows.
- Integrasi System Tray Windows untuk memantau status servis dan kontrol cepat dari taskbar.

## Struktur Kode

```text
lib/
├── models/                       # Model data (site, PHP version, status komponen)
├── services/                     # Logika servis (HTTP server, FastCGI client, MariaDB, Hosts, Engine switcher)
├── theme/                        # Tema dan styling antarmuka
├── views/                        # Tampilan halaman utama
└── widgets/                      # Komponen dialog dan kontrol UI
windows/                          # Runner native Windows C++ dan manifest UAC
test/                             # Pengujian unit test otomatis
```

## Menjalankan Proyek

### Mode Development
```bash
flutter pub get
flutter run -d windows
```

### Menjalankan Unit Test
```bash
flutter test
```

### Kompilasi Release
```bash
flutter build windows --release
```
Hasil file executable dan runtime akan berada di `build/windows/x64/runner/Release/`.
