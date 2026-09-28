# DevlikaStack

**English** | [Bahasa Indonesia](README.md)

A lightweight, resource-efficient local web server and database development environment for Windows built with Flutter desktop. It combines a web server (Native HTTP / Nginx / Apache), multi-version PHP via FastCGI daemon, MariaDB, and phpMyAdmin in a single portable package without modifying the Windows registry.

![DevlikaStack Dashboard](assets/screenshots/preview.png)

---

## Features and Capabilities

### 1. Web Server Engine Choices
Switch between three web server engines directly from the dashboard:
- **Native HTTP Engine**: Internal Dart-based web server listening on ports 80 and 443. Includes a built-in `.htaccess` parser for URL rewriting (compatible with Laravel, CodeIgniter, WordPress, and SPAs), persistent Keep-Alive connections, and an in-memory cache for static files.
- **Nginx 1.26**: Portable Nginx engine with automated virtual host configuration generation (`conf/vhosts/*.conf`).
- **Apache HTTPD 2.4**: Portable Apache HTTPD engine for projects requiring Apache modules.

Engine switching safely releases socket ports 80/443 before binding the new engine.

### 2. Multi-PHP FastCGI Daemon Pool
Unlike traditional local stacks that run only a single global PHP version:
- Run multiple active PHP versions simultaneously (PHP 7.4, 8.1, 8.2, 8.3).
- Configure different PHP versions for each virtual host / project.
- Communication runs via a persistent FastCGI daemon pool (`php-cgi.exe`) on dedicated TCP ports:
  - PHP 7.4: port `9074`
  - PHP 8.1: port `9081`
  - PHP 8.2: port `9082`
  - PHP 8.3: port `9083`
  - Default: port `9000`
- Worker pool managed with `PHP_FCGI_CHILDREN` and OPcache acceleration, avoiding process spawn latency on every HTTP request.

### 3. Database MariaDB & phpMyAdmin
- **MariaDB 3306**: Local database service with dual-stack loopback binding (`127.0.0.1` and `::1`) and `--skip-name-resolve`, eliminating Windows IPv6/DNS lookup timeouts when connecting via `localhost`.
- **phpMyAdmin**: Integrated directly and accessible via browser at `/__phpmyadmin` with automatic credentials.
- **SQL Importer**: Large SQL dump importer using chunked transaction execution to import multi-hundred-megabyte SQL files without memory limits or connection timeouts.

### 4. Virtual Hosts & Hosts File Sync
- Add custom local domains (e.g., `demo.local`, `siakad.id`).
- Automatically updates the Windows hosts file (`C:\Windows\System32\drivers\etc\hosts`) mapping both IPv4 (`127.0.0.1`) and IPv6 (`::1`) so browsers bypass external DNS lookups.
- Auto-detects DocumentRoot: recognizes `public/index.php` (Laravel) and `public_html/index.php` (CodeIgniter or legacy architectures).
- **Reverse Proxy**: Proxies requests from local domains to other backend service ports (Node.js, Go, Python, etc.).

### 5. Local SSL / HTTPS
- Automatically generates local SSL certificates to serve HTTPS traffic on port 443 across all web engines.

### 6. Lightweight, Portable & System Tray
- **Low RAM Usage & No VM Overhead**: Runs natively on Windows without virtualization layers (like Docker Desktop or WSL2 VMs) that consume gigabytes of memory.
- **Minimal Idle Footprint**: Negligible RAM and CPU usage while on standby; services only process resources when requests arrive.
- **Fully Portable**: All PHP binaries, MariaDB, user databases, and configuration files reside within the application directory (`bin/` and `storage/`) without touching the Windows registry.
- **System Tray**: Minimizes to the taskbar tray to monitor service status quietly in the background without hogging resources when opening code editors (VS Code, PhpStorm).
- Configured with a `requireAdministrator` manifest to automatically manage ports 80/443 and the system `hosts` file.

---

## Default Ports and Configuration

| Service | Default Port | Description |
|---|---|---|
| HTTP Web Server | `80` | Native HTTP / Nginx / Apache |
| HTTPS (SSL) | `443` | Automated local SSL certificates |
| MariaDB | `3306` | User: `root`, Password: *(empty)* |
| phpMyAdmin | `80` | Access via `http://localhost/__phpmyadmin` |
| FastCGI PHP 7.4 | `9074` | Persistent worker pool daemon |
| FastCGI PHP 8.1 | `9081` | Persistent worker pool daemon |
| FastCGI PHP 8.2 | `9082` | Persistent worker pool daemon |
| FastCGI PHP 8.3 | `9083` | Persistent worker pool daemon |

---

## Building from Source

Prerequisites:
- Flutter SDK (3.12+)
- Visual Studio (with *Desktop development with C++* workload)
- Windows 10/11 64-bit

```bash
# Fetch dependencies
flutter pub get

# Run unit tests
flutter test

# Build release executable
flutter build windows --release
```
