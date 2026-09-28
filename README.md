# DevlikaStack

Aplikasi desktop Windows untuk web server lokal (PHP, MariaDB, Nginx, Apache) berbasis Flutter. Dibuat supaya bisa development web di Windows secara portable tanpa perlu setup yang ribet.

## Fitur

- **Web Server**: Bisa pilih engine bawaan, Nginx, atau Apache di port 80 & 443. Sudah support rewrite `.htaccess` untuk Laravel, CodeIgniter, WordPress, dan SPA.
- **Multi-PHP**: Bisa jalanin PHP 7.4, 8.1, 8.2, dan 8.3 secara bersamaan. Versi PHP bisa diatur berbeda untuk tiap domain/projek. Dijalankan lewat daemon FastCGI (`php-cgi`) dengan worker pool biar respon web tetap cepat.
- **MariaDB & phpMyAdmin**: MariaDB langsung aktif di port 3306 (user `root` tanpa password) dengan koneksi dual-stack IPv4/IPv6 biar tidak ada delay saat panggil `localhost`. Sudah include phpMyAdmin dan tool import SQL untuk file dump besar.
- **Virtual Host & Auto Hosts**: Tambah domain lokal (contoh `projek.test`), otomatis sync ke file `hosts` Windows. Otomatis deteksi folder root `public` atau `public_html`.
- **Reverse Proxy**: Bisa mapping domain lokal ke port service lain seperti Node.js, Python, atau Go.
- **SSL Lokal**: Otomatis buat sertifikat SSL lokal untuk akses HTTPS di port 443.
- **Portable**: Semua runtime PHP, MariaDB, database, dan konfigurasi tersimpan di dalam folder aplikasi, jadi gampang dipindah tanpa ngotorin registry Windows.
- **System Tray**: Bisa diminimize ke tray taskbar untuk monitor status servis.

## Cara Build

Prasyarat: Flutter SDK dan Visual Studio (Desktop C++).

```bash
# install package
flutter pub get

# run mode dev
flutter run -d windows

# compile release
flutter build windows --release
```

Hasil build release tersimpan di `build/windows/x64/runner/Release/`.
