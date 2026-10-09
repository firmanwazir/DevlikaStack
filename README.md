# DevlikaStack v2.2

A lightweight, portable local web server and database development environment for Windows, built with Flutter. DevlikaStack bundles a multi-engine web server (Native HTTP, Nginx, Apache), a multi-version PHP FastCGI daemon pool, visual PHP extension management, MariaDB, phpMyAdmin, custom port conflict prevention, and 1-click Cloudflare Quick Tunnel into a single portable package without requiring Windows registry modifications or heavy virtualization layers.

![DevlikaStack Dashboard](assets/screenshots/preview.png)

---

## What's New in v2.2

* ⚡ **Visual PHP Extension Switch & php.ini Manager**: Toggle PHP extensions on/off with visual switches and instant FastCGI hot-reload (no server restart required). Includes 1-click presets for **Laravel**, **WordPress**, and **Minimal**, automated Zend OPcache directive synchronization, and cross-version GD variant resolution (PHP 7.4 vs 8.x).
* 🚀 **0ms In-Memory Extensions Search & Multi-Sorting**: Filter extensions instantly with zero disk I/O stutter. Supports sorting by **Aktif di Atas (Active first)**, **Nama (A - Z)**, **Nama (Z - A)**, and **Kategori**, plus status filters (**Hanya Aktif** / **Hanya Nonaktif**) and responsive `Wrap` category chips.
* 🛡️ **Custom Port Conflict Management (Anti-Bentrok XAMPP)**: Automatically detects occupied ports (such as port 80 or 3306 used by XAMPP) and suggests free alternative socket ports (e.g. 8080, 3307) with full settings persistence.
* 🔒 **Single-Instance Protection (Anti-Bentrok Instance)**: Native Win32 Mutex and Dart loopback guard prevent opening duplicate application instances, cleanly restoring and focusing the active window without process or database contention.
* 💫 **Interactive Loading Feedback**: Instant lightweight loading spinners and dynamic status updates on "Start All", "Stop All", and individual service toggles to prevent double-clicks and reassure users.
* 🎨 **Modern Obsidian/Zinc UI Overhaul**: Sleek dark aesthetic across all views, cards, modals, and logs.
* 🧪 **Comprehensive Test Coverage**: 53 unit tests covering extensions parser, port conflict manager, Cloudflare tunnels, virtual hosts, and reverse proxy routing.

---

## Features & Architecture

### 1. Visual PHP Extension Switch & php.ini Manager
- **Visual Switch On/Off**: Enable or disable PHP extensions (`curl`, `intl`, `pdo_mysql`, `mbstring`, `zip`, `gd`, `fileinfo`, `sodium`, etc.) with a single click.
- **FastCGI Hot-Reload**: Changes to `php.ini` trigger debounced worker pool reloads instantly without interrupting other running services.
- **Zend OPcache & GD Automation**: Automatically manages `zend_extension=opcache` and `opcache.enable = 1`. Automatically cleans up `extension=gd2` vs `extension=gd` between PHP 7.4 and PHP 8.x.
- **1-Click Presets**:
  - **Laravel**: Activates all required extensions (`pdo_mysql`, `openssl`, `mbstring`, `curl`, `intl`, `gd`, `fileinfo`, `zip`, `opcache`).
  - **WordPress**: Activates WordPress requirements (`mysqli`, `curl`, `gd`, `intl`, `mbstring`, `openssl`, `zip`, `exif`, `fileinfo`, `opcache`).
  - **Minimal**: Lightweight baseline setup (`pdo_mysql`, `mbstring`, `openssl`, `curl`).
- **Responsive 2-Tier Toolbar**: Search bar with clear button, status filter, sort dropdown, and full-width `Wrap` category chips with colored badges showing active counts (e.g., `Database 3/6`).
- **Visual Directives Editor**: Edit essential `php.ini` directives directly (`memory_limit`, `upload_max_filesize`, `post_max_size`, `max_execution_time`, `max_input_vars`, `date.timezone`, `display_errors`, `cgi.fix_pathinfo`).

### 2. Multi-Engine Web Server
DevlikaStack offers three switchable web server engines managed directly from the dashboard:
- **Native HTTP Engine**: A built-in Dart-based web server listening on port 80 (or custom port). Includes an integrated `.htaccess` parser for URL rewrites (compatible with Laravel, CodeIgniter, WordPress, and Single Page Applications), Keep-Alive persistent connection pooling, and in-memory static file caching for sub-millisecond asset delivery.
- **Nginx 1.26**: Portable Nginx engine with automated virtual host configuration generation (`conf/vhosts/*.conf`).
- **Apache HTTPD 2.4**: Portable Apache engine for projects requiring specific Apache modules or traditional `.htaccess` workflows.

Engine switching cleanly releases existing socket bindings before initializing the selected engine to prevent port collision.

### 3. Multi-PHP FastCGI Daemon Pool
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

### 4. MariaDB & Database Management
- **MariaDB Local Service**: Configured with dual-stack loopback binding (`127.0.0.1` and `::1`), 64MB query cache, and `--skip-name-resolve` to eliminate Windows IPv6/localhost DNS resolution delays. Default credentials: user `root`, no password. Port default `3306` (customizable).
- **Integrated phpMyAdmin**: Accessible via `http://localhost:<port>/__phpmyadmin` with automated authentication to the local database instance.
- **Turbo SQL Importer**: High-throughput SQL dump importer utilizing chunked transaction buffering, enabling multi-hundred-megabyte database imports without memory exhaustion or script timeouts.

### 5. Virtual Hosts & Automated Hosts File Sync
- Add custom local domains (e.g. `demo.local`, `siakad.id`).
- Automatically synchronizes with the Windows `hosts` file (`C:\Windows\System32\drivers\etc\hosts`) using dual IPv4 (`127.0.0.1`) and IPv6 (`::1`) mapping to bypass external DNS lookups.
- Automatic DocumentRoot detection: intelligently identifies `public/index.php` (Laravel) or `public_html/index.php` (CodeIgniter/traditional layouts).
- **Reverse Proxy**: Forward local domain traffic to external backend services (Node.js, Go, Python, etc.) running on custom local ports.

### 6. 1-Click Cloudflare Quick Tunnel (Public Preview)
- **Instant Client Previews**: Share any local virtual host or custom local port directly to the internet with a single click.
- **Valid Official HTTPS Certificate**: Powered by Cloudflare Anycast edge, ensuring clients never see browser security or certificate warnings.
- **Zero Configuration**: Uses Cloudflare Quick Tunnels — no account creation, credit card, or auth tokens required. 100% free and unlimited bandwidth.
- **Virtual Host Preservation**: Automatically routes with `--http-host-header`, ensuring Nginx, Apache, and Native HTTP engines route requests to the correct virtual host.
- **Auto-Reconnect**: If the free tunnel drops unexpectedly, DevlikaStack automatically reconnects with exponential backoff (up to 5 attempts).
- **Automated Binary Provisioning**: Downloads official `cloudflared` binary on-demand (~55 MB) directly into `bin/tools/` with in-app download progress.

### 7. Custom Port Conflict Prevention
- Works harmoniously alongside existing installations like XAMPP, WampServer, or IIS.
- Customize Web Server port (e.g. `8080` instead of `80`) and MariaDB port (e.g. `3307` instead of `3306`).
- Automatic socket availability tester warns if a selected port is in use and recommends an open port.

### 8. Lightweight, Portable & System Tray
- **Low RAM & Non-VM**: Runs natively on Windows without Docker Desktop, WSL2, or virtual machine overhead.
- **Minimal Idle Footprint**: Near-zero idle CPU and memory consumption.
- **Self-Contained & Portable**: All PHP binaries, MariaDB data, web engines, and configuration files live inside the application directory (`bin/` and `storage/`). No Windows registry keys are altered.
- **System Tray Integration**: Minimizes to the Windows system tray for background operation while monitoring service statuses.

---

## Port Allocations (Configurable)

| Service | Default Port | Alternative (Anti-Conflict) | Description |
|---|---|---|---|
| HTTP Web Server | `80` | `8080`, `8000` | Native HTTP / Nginx / Apache |
| MariaDB | `3306` | `3307`, `3308` | User: `root`, Password: *(empty)* |
| phpMyAdmin | Web Port | Web Port | Accessible via `http://localhost:<port>/__phpmyadmin` |
| FastCGI PHP 7.4 | `9074` | — | Multi-worker parallel pool |
| FastCGI PHP 8.1 | `9081` | — | Multi-worker parallel pool |
| FastCGI PHP 8.2 | `9082` | — | Multi-worker parallel pool |
| FastCGI PHP 8.3 | `9083` | — | Multi-worker parallel pool |

---

## Download & Installation

1. Download **`DevlikaStack-v2.2-windows-x64.zip`** from [GitHub Releases](https://github.com/firmanwazir/DevlikaStack/releases/tag/v2.2).
2. Extract the archive into your preferred directory (e.g., `D:\DevlikaStack-Portable\`).
3. Run **`DevlikaStack.exe`** as Administrator.

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

---

## License

DevlikaStack is open-source software licensed under the MIT License.
