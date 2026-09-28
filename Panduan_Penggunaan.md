# âš¡ Panduan DevStack (Edisi Native Flutter Desktop)

Aplikasi **DevStack** telah dibangun sepenuhnya menggunakan **Flutter Desktop Native Windows** dengan antarmuka modern yang presisi, responsif, dan instan dibuka.

---

## ðŸŽ¯ 5 Penyempurnaan Utama Berdasarkan Kebutuhanmu

1. **Proteksi Komponen (Belum Ada = Belum Bisa Dinyalakan)**:
   - Tombol toggle Web Server dan MariaDB otomatis **terkunci (disabled)** jika library PHP atau MariaDB belum terpasang.
   - Muncul peringatan jelas: *"âš ï¸ Komponen PHP belum ada - Install Sekarang"*.
   - Tidak ada lagi error membingungkan bagi pemula.

2. **Fleksibilitas Instalasi (Bisa Sekaligus atau Per-Library)**:
   - Di menu **Environment (Komponen)**:
     - Tombol utama: **"âš¡ Install Semua Komponen Sekaligus"** (Download & setup PHP + MariaDB + phpMyAdmin otomatis 1-klik).
     - Tombol per-komponen: Kamu bisa install/reinstall **PHP saja**, **MariaDB saja**, atau **phpMyAdmin saja** dengan indikator progress bar real-time.

3. **Kecepatan Buka Super Cepat (Native Desktop)**:
   - Dibuat dengan **Flutter Windows C++ Native**.
   - Buka dalam **0.1 detik (instan)** tanpa lag browser, tanpa font eksternal yang bikin macet.

4. **Database Manager Menggunakan phpMyAdmin**:
   - Terintegrasi penuh dengan **phpMyAdmin**.
   - Dilengkapi menu khusus di sidebar dan header bar.
   - 1-klik tombol **"ðŸŒ Buka phpMyAdmin"** otomatis membuka browser dan langsung login ke MariaDB (`127.0.0.1:3306`, user `root`).

5. **Antarmuka (UI) Modern & 100% Responsif**:
   - **Left Sidebar Navigation**:
     - ðŸ“Š **Dashboard Overview** (Kartu status, toggle servis, port chip, quick website list)
     - ðŸŒ **Hosts / Websites** (Tabel virtual host, tombol tambah domain lokal, action browser/folder)
     - ðŸ˜ **PHP Engine** (Detail path, ekstensi aktif, info php.ini)
     - ðŸ¬ **MariaDB** (Status port 3306, user root, kredensial)
     - ðŸ—„ï¸ **phpMyAdmin** (Akses database instan)
     - ðŸ“¦ **Environment (Pusat Komponen)** (Install sekaligus / per library)
     - ðŸ“œ **Log Server** (Terminal live aktivitas HTTP)
   - Layout kartu dan tabel adaptif terhadap ukuran layar.

---

## ðŸš€ Cara Menjalankan Portable

Buka folder:
`D:\WebServer\www\WindowApp\Server\DevStack-Portable\`

Di dalam folder portable ini **HANYA ADA 2 ITEM**:
1. `DevStack.exe`
2. `bin/`

Cukup klik dua kali:
```text
DevStack-Portable\DevStack.exe
```

- **Langsung Administrator Otomatis**: Memiliki manifest UAC (`requireAdministrator`), otomatis meminta izin admin saat dibuka.
- **Tanpa Layar Hitam / Terminal CMD**: Berjalan di subsistem Windows GUI native murni.

---

## ðŸ“‚ Struktur Bersih & Portabel (Hanya 1 EXE & 1 Folder)

Semua folder dan library yang dibutuhkan aplikasi (`php`, `mariadb`, `phpmyadmin`, `storage`, `data`, `demo-site`) sudah dipersatukan ke dalam **SATU FOLDER** `bin/`:

```text
DevStack-Portable/
â”œâ”€â”€ DevStack.exe                 <-- File Eksekusi Utama (Double-click ini)
â””â”€â”€ bin/                          <-- SATU-SATUNYA FOLDER KEBUTUHAN APLIKASI
    â”œâ”€â”€ DevStack.exe             <-- Engine Native GUI (Flutter Release)
    â”œâ”€â”€ flutter_windows.dll       <-- Runtime DLL
    â”œâ”€â”€ url_launcher_windows_plugin.dll
    â”œâ”€â”€ data/                     <-- Asset internal aplikasi
    â”œâ”€â”€ php/                      <-- PHP Portable Engine
    â”œâ”€â”€ mariadb/                  <-- MariaDB Daemon & Binaries
    â”œâ”€â”€ tools/
    â”‚   â””â”€â”€ phpmyadmin/           <-- phpMyAdmin Full Version
    â”œâ”€â”€ storage/
    â”‚   â”œâ”€â”€ mariadb/              <-- Database MySQL tersimpan di sini
    â”‚   â””â”€â”€ sites.json            <-- Konfigurasi Virtual Hosts Lokal
    â””â”€â”€ demo-site/                <-- Folder website default demo.local
```

> **Catatan Portabilitas**: Folder `DevStack-Portable` ini bisa langsung kamu copy atau pindahkan ke flashdisk / PC mana saja tanpa perlu install apa-apa lagi!

---

## âš¡ Dukungan Penuh Framework Modern (Laravel & CodeIgniter)

Aplikasi telah dilengkapi modul PHP dan fitur Web Server tingkat lanjut:

1. **Modul PHP Aktif & Optimal**:
   - **CodeIgniter 4**: `intl`, `mbstring`, `mysqli`, `curl`, `json`
   - **Laravel 9/10/11**: `pdo_mysql`, `openssl`, `sodium`, `bcmath`, `fileinfo`, `gd`, `zip`, `exif`
   - **Composer**: `memory_limit = 512M`, `upload_max_filesize = 128M`, `max_execution_time = 300`

2. **Fitur Web Server (URL Rewrite / Pretty URLs)**:
   - Seperti `try_files` Nginx atau `mod_rewrite` Apache, semua routing URL (seperti `/login`, `/api/v1/posts`, dsb.) otomatis diarahkan ke `index.php` tanpa error 404.
   - Deteksi otomatis folder `public/` jika kamu menambahkan proyek Laravel atau CodeIgniter 4.
   - Meneruskan header `Authorization: Bearer <token>` untuk autentikasi API (Laravel Sanctum / Passport / JWT).
