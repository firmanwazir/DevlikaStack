# DevlikaStack

A lightweight, portable local web development environment for Windows, built with Flutter desktop. Designed as a modular and modern alternative to traditional stacks like XAMPP and Laragon.

---

## Overview

DevlikaStack provides a self-contained environment for running PHP, MariaDB, and web servers locally on Windows. It requires no system-wide installation or registry modifications, keeping all binaries, configurations, virtual hosts, and databases isolated within a single directory.

---

## Features

### Multi-Engine Web Server
- **Native HTTP Engine**: Built-in HTTP/HTTPS server with integrated `.htaccess` rewriting, persistent Keep-Alive connections, and an in-memory cache for static assets.
- **Nginx Portable**: Pre-configured Nginx engine with automated virtual host generation.
- **Apache HTTPD**: Apache 2.4 integration for environments requiring Apache modules.
- **Engine Switching**: Switch active engines on port 80/443 directly from the dashboard without conflicting socket bindings.

### Multi-PHP Runtime & FastCGI Daemon Pool
- Run multiple PHP versions simultaneously (e.g., PHP 7.4, 8.1, 8.2, 8.3).
- Assign specific PHP versions on a per-site basis.
- Persistent FastCGI worker processes with OPcache acceleration to minimize per-request process creation overhead.
- Dual-stack loopback support (`127.0.0.1` and `::1`) with tuned realpath cache and OPcache configurations.

### Database Management
- **MariaDB Portable**: Runs locally on port 3306 with dual-stack loopback binding (`127.0.0.1,::1`) and DNS lookup bypass (`--skip-name-resolve`) to ensure instant local connection handshakes.
- **Integrated phpMyAdmin**: Quick browser access with automatic credential management.
- **High-Speed Database Importer**: Built-in SQL dump importer designed to handle large database files efficiently using chunked streaming and session-level optimizations (`max_allowed_packet`, bulk insert buffers, transaction commit tuning).

### Virtual Hosts & Routing
- Automatic synchronization with the Windows `hosts` file (`C:\Windows\System32\drivers\etc\hosts`) mapping both IPv4 and IPv6 loopback addresses.
- Auto-detection of framework entry points (`public/index.php`, `public_html/index.php`) for frameworks like Laravel, CodeIgniter, and WordPress.
- Reverse proxy support for Node.js, Python, Go, or other backend services.
- Built-in `.htaccess` parser supporting URL rewrites, redirects, header rules, and access control.

### SSL / HTTPS
- Automated local SSL certificate generation for port 443.
- Native HTTPS support across the built-in engine, Nginx, and Apache.

### Portable & Desktop Native
- Fully portable: runs directly from any folder or USB drive.
- Windows System Tray integration with service status indicators and quick actions.
- UAC manifest configuration requesting administrative privileges on launch to manage port 80 and the `hosts` file.

---

## Directory Structure

```text
DevlikaStack-Portable/
├── DevlikaStack.exe              # Main application executable
├── flutter_windows.dll           # Flutter Windows runtime
├── data/                         # Application assets and AOT compiled code
└── bin/                          # Isolated runtime binaries and storage
    ├── php/                      # PHP runtimes (e.g., php-7.4, php-8.2)
    │   ├── php-7.4/
    │   └── php-8.2/
    ├── mariadb/                  # MariaDB portable binaries
    ├── nginx/                    # Nginx portable server and vhost configs
    ├── apache/                   # Apache HTTPD server configuration
    ├── tools/
    │   └── phpmyadmin/           # phpMyAdmin installation
    └── storage/                  # User databases, virtual host configs, and SSL certs
        ├── mariadb/              # MariaDB data directory
        ├── ssl/                  # Local SSL certificates
        ├── sites.json            # Virtual host definitions
        └── settings.json         # Application preferences
```

---

## Getting Started

### Using the Portable Release

1. Download or extract `DevlikaStack-Portable` to any directory of your choice (e.g., `D:\DevlikaStack`).
2. Run `DevlikaStack.exe`. The application will request administrator privileges to bind low-numbered ports (80/443) and manage local domain entries in the `hosts` file.
3. Open the **Environment / Components** tab to install or verify your desired PHP versions, MariaDB, and phpMyAdmin.
4. Add your project in the **Hosts / Websites** section, configure the domain name (e.g., `myproject.local`), and select the desired PHP version.

### Default Database Credentials

- **Host**: `127.0.0.1` (or `localhost`)
- **Port**: `3306`
- **Username**: `root`
- **Password**: *(empty / no password)*

---

## Building from Source

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install/windows) (version 3.12.0 or higher)
- Visual Studio 2022 with the "Desktop development with C++" workload
- Windows 10 or 11 (64-bit)

### Build Steps

1. Clone the repository:
   ```bash
   git clone https://github.com/your-username/DevlikaStack.git
   cd DevlikaStack
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run automated tests:
   ```bash
   flutter test
   ```

4. Build the release binary:
   ```bash
   flutter build windows --release
   ```

The compiled binary and runtime files will be generated in `build/windows/x64/runner/Release/`.

---

## Tech Stack

- **UI & Application Core**: Flutter Desktop (Dart / C++ Runner)
- **State Management & Architecture**: Singleton service pattern with reactive streams
- **Desktop Plugins**: `window_manager`, `tray_manager`, `screen_retriever`, `url_launcher`
- **Web Protocol Implementation**: Native FastCGI client, dual-stack HTTP/HTTPS server, `.htaccess` rule engine

---

## License

This project is licensed under the [MIT License](LICENSE).
