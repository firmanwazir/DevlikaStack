# DevlikaStack

Aplikasi desktop Windows untuk manajemen web server lokal dan database development environment.

## Fitur & Kemampuan

### Web Server
- **Engine**: Mendukung Native HTTP Server, Nginx, dan Apache.
- **Port**: Berjalan di port 80 (HTTP) dan port 443 (HTTPS).
- **Rewrite**: Parser `.htaccess` bawaan untuk URL rewriting (Laravel, CodeIgniter, WordPress, SPA).
- **SSL**: Pembuatan sertifikat SSL lokal otomatis untuk pengujian HTTPS.

### PHP Runtime & FastCGI
- **Multi-Version**: Menjalankan beberapa versi PHP secara bersamaan (PHP 7.4, 8.1, 8.2, 8.3).
- **Per-Site PHP**: Versi PHP dapat ditentukan berbeda untuk setiap domain / virtual host.
- **FastCGI Pool**: Koneksi daemon `php-cgi` via TCP socket dengan worker process persistent.
- **Optimasi**: Konfigurasi realpath cache dan default host database `127.0.0.1`.

### Database
- **MariaDB**: Berjalan di port 3306 dengan binding dual-stack loopback (`127.0.0.1` dan `::1`) serta `--skip-name-resolve`.
- **phpMyAdmin**: Terintegrasi langsung dengan kredensial default MariaDB.
- **SQL Importer**: Import database file `.sql` ukuran besar dengan eksekusi bertahap (chunked streaming).

### Virtual Host & Routing
- **Custom Domain**: Penambahan domain lokal dengan sinkronisasi otomatis ke file Windows `hosts`.
- **Auto-Detect Root**: Deteksi otomatis folder root proyek (`public` atau `public_html`).
- **Reverse Proxy**: Meneruskan request domain ke port aplikasi backend lain (Node.js, Go, Python).

### Portabilitas
- **Portable**: Seluruh binary runtime, data MariaDB, dan konfigurasi tersimpan dalam satu folder aplikasi.
- **System Tray**: Monitoring status service dan kontrol cepat dari taskbar Windows.

## Struktur Project

```text
lib/
├── models/       # Data models
├── services/     # Engine service (HTTP, FastCGI, MariaDB, Hosts, Engine switcher)
├── theme/        # UI theme & styling
├── views/        # Page views
└── widgets/      # Reusable UI components
windows/          # Windows C++ runner & manifest UAC
test/             # Unit tests
```

## Build & Run

### Menjalankan Development
```bash
flutter pub get
flutter run -d windows
```

### Menjalankan Test
```bash
flutter test
```

### Build Release
```bash
flutter build windows --release
```
Binary release akan dibuat di `build/windows/x64/runner/Release/`.
