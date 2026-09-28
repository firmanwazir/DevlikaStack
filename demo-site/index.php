<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Selamat Datang di Web Lokal!</title>
    <style>
        body {
            background: #090d16;
            color: #f8fafc;
            font-family: system-ui, -apple-system, sans-serif;
            display: flex;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
            margin: 0;
            padding: 20px;
        }
        .container {
            background: rgba(17, 24, 39, 0.9);
            border: 1px solid rgba(255, 255, 255, 0.1);
            border-radius: 20px;
            padding: 40px;
            max-width: 650px;
            box-shadow: 0 20px 50px rgba(0,0,0,0.6);
            text-align: center;
        }
        .icon { font-size: 56px; margin-bottom: 12px; }
        h1 { color: #38bdf8; margin: 0 0 10px; font-size: 28px; }
        p { color: #94a3b8; line-height: 1.6; }
        .grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 16px;
            margin: 24px 0;
            text-align: left;
        }
        .card {
            background: #0b0f19;
            border: 1px solid rgba(255, 255, 255, 0.06);
            border-radius: 12px;
            padding: 16px;
        }
        .card h3 { margin: 0 0 6px; font-size: 14px; color: #cbd5e1; }
        .badge {
            display: inline-block;
            padding: 4px 10px;
            border-radius: 6px;
            font-weight: 700;
            font-size: 12px;
        }
        .badge-success { background: rgba(16, 185, 129, 0.2); color: #34d399; }
        .badge-error { background: rgba(239, 68, 68, 0.2); color: #f87171; }
        .footer {
            font-size: 13px;
            color: #64748b;
            border-top: 1px solid rgba(255, 255, 255, 0.06);
            padding-top: 16px;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="icon">🚀</div>
        <h1>Website Lokal Berhasil Berjalan!</h1>
        <p>Halaman ini disajikan oleh <b>ServerApp</b> menggunakan PHP dan MariaDB mandiri.</p>

        <div class="grid">
            <div class="card">
                <h3>Versi PHP & Ekstensi</h3>
                <span class="badge badge-success">PHP <?php echo phpversion(); ?> (Portable)</span>
                <div style="font-size: 11px; color: #94a3b8; margin-top: 6px;">
                    <?php 
                    $checkExts = ['pdo_mysql', 'intl', 'mbstring', 'openssl', 'sodium', 'curl', 'gd'];
                    $loaded = array_filter($checkExts, 'extension_loaded');
                    echo count($loaded) . '/' . count($checkExts) . ' Modul Framework Aktif';
                    ?>
                </div>
            </div>
            <div class="card">
                <h3>Koneksi MariaDB (Port 3306)</h3>
                <?php
                $dbConnected = false;
                $dbError = '';
                try {
                    $conn = @new mysqli('127.0.0.1', 'root', '');
                    if ($conn->connect_error) {
                        $dbError = $conn->connect_error;
                    } else {
                        $dbConnected = true;
                        $conn->close();
                    }
                } catch (Exception $e) {
                    $dbError = $e->getMessage();
                }

                if ($dbConnected): ?>
                    <span class="badge badge-success">Terhubung Sukses!</span>
                <?php else: ?>
                    <span class="badge badge-error">Belum Aktif / <?php echo htmlspecialchars($dbError); ?></span>
                <?php endif; ?>
            </div>
        </div>

        <div style="background: rgba(0, 210, 255, 0.08); border: 1px solid rgba(0, 210, 255, 0.25); border-radius: 12px; padding: 12px 16px; margin-bottom: 20px; font-size: 12px; text-align: left; color: #e2e8f0;">
            <strong style="color: #00D2FF;">⚡ Siap untuk Laravel & CodeIgniter:</strong>
            <ul style="margin: 6px 0 0 16px; padding: 0; line-height: 1.6; color: #94a3b8;">
                <li><strong>URL Rewrite:</strong> Pretty URLs (<code>try_files</code>) aktif (routing <code>/login</code>, <code>/api</code>, dll.)</li>
                <li><strong>CodeIgniter 4:</strong> Modul <code>intl</code>, <code>mbstring</code>, <code>mysqli</code> aktif</li>
                <li><strong>Laravel 9/10/11:</strong> Modul <code>pdo_mysql</code>, <code>openssl</code>, <code>sodium</code>, <code>bcmath</code> aktif</li>
                <li><strong>Composer Limit:</strong> <code>memory_limit = 512M</code>, <code>upload_max = 128M</code></li>
            </ul>
        </div>

        <div class="footer">
            Server Time: <?php echo date('Y-m-d H:i:s'); ?> | Host: <?php echo htmlspecialchars($_SERVER['HTTP_HOST'] ?? 'localhost'); ?>
        </div>
    </div>
</body>
</html>
