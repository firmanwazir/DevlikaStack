# DevlikaStack

A lightweight, portable local web server and database development environment for Windows, built with Flutter. DevlikaStack bundles a multi-engine web server (Native HTTP, Nginx, Apache), a multi-version PHP FastCGI daemon pool, MariaDB, and phpMyAdmin into a single portable package without requiring Windows registry modifications or heavy virtualization layers.

![DevlikaStack Dashboard](assets/screenshots/preview.png)

---

## Features & Architecture

### 1. Multi-Engine Web Server
DevlikaStack offers three switchable web server engines managed directly from the dashboard:
- **Native HTTP Engine**: A built-in Dart-based web server listening on port 80. Includes an integrated `.htaccess` parser for URL rewrites (fully compatible with Laravel, CodeIgniter, WordPress, and Single Page Applications), Keep-Alive persistent connection pooling, and in-memory static file caching for sub-millisecond asset delivery.
- **Nginx 1.26**: Portable Nginx engine with automated virtual host configuration generation (`conf/vhosts/*.conf`).
- **Apache HTTPD 2.4**: Portable Apache engine for projects requiring specific Apache modules or traditional `.htaccess` workflows.

Engine switching releases existing socket bindings on port 80 before initializing the selected engine to prevent port collision.

### 2. Multi-PHP FastCGI Daemon Pool
Unlike traditional local stacks that enforce a single global PHP version:
- Run multiple PHP versions concurrently (PHP 7.4, 8.1, 8.2, and 8.3).
- Assign specific PHP runtimes per virtual host or project.
- FastCGI daemon communication runs via dedicated TCP ports with multi-worker concurrency pools:
  - PHP 7.4: primary port `9074` (multi-worker pool: `9074..9374`)
  - PHP 8.1: primary port `9081` (multi-worker pool: `9081..9381`)
  - PHP 8.2: primary port `9082` (multi-worker pool: `9082..9382`)
  - PHP 8.3: primary port `9083` (multi-worker pool: `9083..9383`)
  - Default fallback: primary port `9000` (multi-worker pool: `9000..9003`)
- Multi-worker pools and OPcache pre-compilation eliminate per-request process spawn overhead and ensure instantaneous response times.

### 3. MariaDB & Database Management
- **MariaDB 3306**: Local database service configured with dual-stack loopback binding (`127.0.0.1` and `::1`), 64MB query cache, and `--skip-name-resolve` to eliminate Windows IPv6/localhost DNS resolution delays. Default credentials: user `root`, no password.
- **Integrated phpMyAdmin**: Accessible via `http://localhost/__phpmyadmin` with automated authentication to the local database instance.
- **Chunked SQL Importer**: High-throughput SQL dump importer utilizing chunked transaction buffering, enabling multi-hundred-megabyte database imports without memory exhaustion or script timeouts.

### 4. Virtual Hosts & Automated Hosts File Sync
- Add custom local domains (e.g. `demo.local`, `siakad.id`).
- Automatically synchronizes with the Windows `hosts` file (`C:\Windows\System32\drivers\etc\hosts`) using dual IPv4 (`127.0.0.1`) and IPv6 (`::1`) mapping to bypass external DNS lookups.
- Automatic DocumentRoot detection: intelligently identifies `public/index.php` (Laravel) or `public_html/index.php` (CodeIgniter/traditional layouts).
- **Reverse Proxy**: Forward local domain traffic to external backend services (Node.js, Go, Python, etc.) running on custom local ports.

### 5. Lightweight, Portable & System Tray
- **Low RAM & Non-VM**: Runs natively on Windows without Docker Desktop, WSL2, or virtual machine overhead, preserving system RAM for IDEs and compilers.
- **Minimal Idle Footprint**: Near-zero idle CPU and memory consumption; services only consume processing cycles when handling active requests.
- **Self-Contained & Portable**: All PHP binaries, MariaDB data, web engines, and configuration files live inside the application directory (`bin/` and `storage/`). No Windows registry keys are altered.
- **System Tray Integration**: Minimizes to the Windows system tray for background operation while monitoring service statuses.

---

## Default Port Allocations

| Service | Default Port | Description |
|---|---|---|
| HTTP Web Server | `80` | Native HTTP / Nginx / Apache |
| MariaDB | `3306` | User: `root`, Password: *(empty)* |
| phpMyAdmin | `80` | Accessible via `http://localhost/__phpmyadmin` |
| FastCGI PHP 7.4 | `9074` | Multi-worker parallel pool |
| FastCGI PHP 8.1 | `9081` | Multi-worker parallel pool |
| FastCGI PHP 8.2 | `9082` | Multi-worker parallel pool |
| FastCGI PHP 8.3 | `9083` | Multi-worker parallel pool |

---

## Building from Source

### Prerequisites
- Flutter SDK (3.12 or newer)
- Visual Studio with the **Desktop development with C++** workload
- Windows 10/11 64-bit

```bash
# Fetch dependencies
flutter pub get

# Run test suite
flutter test

# Compile release executable
flutter build windows --release
```
