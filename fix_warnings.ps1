# fix_warnings.ps1
# Jalankan dari root folder project: .\fix_warnings.ps1

Write-Host "Fixing withOpacity deprecations..." -ForegroundColor Cyan

$files = Get-ChildItem -Path "lib" -Recurse -Filter "*.dart"

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw -Encoding UTF8
    $original = $content

    # Ganti semua .withOpacity(X) → .withValues(alpha: X)
    $content = $content -replace '\.withOpacity\(([^)]+)\)', '.withValues(alpha: $1)'

    if ($content -ne $original) {
        Set-Content $file.FullName $content -Encoding UTF8 -NoNewline
        Write-Host "  Fixed: $($file.FullName)" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Fixing specific warnings in individual files..." -ForegroundColor Cyan

# ── auth_provider.dart: unnecessary cast (result as List) ──────────────────
$path = "lib\providers\auth_provider.dart"
if (Test-Path $path) {
    $c = Get-Content $path -Raw -Encoding UTF8
    # Fix: (result as List).isEmpty → (result as List?)?.isEmpty ?? true
    $c = $c -replace 'if \(result == null \|\| \(result as List\)\.isEmpty\) \{',
        'final resultList = result as List?;
      if (resultList == null || resultList.isEmpty) {'
    $c = $c -replace 'final row = \(result as List\)\.first as Map<String, dynamic>;',
        'final row = resultList!.first as Map<String, dynamic>;'
    Set-Content $path $c -Encoding UTF8 -NoNewline
    Write-Host "  Fixed: $path" -ForegroundColor Green
}

# ── login_screen.dart: unused variable + curly braces ─────────────────────
$path = "lib\screens\login_screen.dart"
if (Test-Path $path) {
    $c = Get-Content $path -Raw -Encoding UTF8
    # Hapus baris unused variable isLogin
    $c = $c -replace '\s*final isLogin\s*=\s*[^\n]+\n', "`n"
    # Fix curly braces: else _onKeypad(key); → else { _onKeypad(key); }
    $c = $c -replace 'if \(isDelete\) _onDelete\(\);\s*\n\s*else _onKeypad\(key\);',
        'if (isDelete) { _onDelete(); } else { _onKeypad(key); }'
    Set-Content $path $c -Encoding UTF8 -NoNewline
    Write-Host "  Fixed: $path" -ForegroundColor Green
}

# ── receipt_screen.dart: unused field _pdfBytes ────────────────────────────
$path = "lib\screens\receipt_screen.dart"
if (Test-Path $path) {
    $c = Get-Content $path -Raw -Encoding UTF8
    $c = $c -replace '\s*Uint8List\? _pdfBytes;\s*\n', "`n"
    $c = $c -replace '\s*setState\(\(\) => _pdfBytes = bytes\);\s*\n', "`n"
    Set-Content $path $c -Encoding UTF8 -NoNewline
    Write-Host "  Fixed: $path" -ForegroundColor Green
}

# ── barista_queue_screen.dart: unused variable status ─────────────────────
$path = "lib\screens\barista_queue_screen.dart"
if (Test-Path $path) {
    $c = Get-Content $path -Raw -Encoding UTF8
    $c = $c -replace '\s*final status\s*=\s*order\[.status.\][^\n]*\n', "`n"
    Set-Content $path $c -Encoding UTF8 -NoNewline
    Write-Host "  Fixed: $path" -ForegroundColor Green
}

# ── pdf_service.dart: unused variable labelStyle ──────────────────────────
$path = "lib\logic\pdf_service.dart"
if (Test-Path $path) {
    $c = Get-Content $path -Raw -Encoding UTF8
    $c = $c -replace '\s*final labelStyle\s*=[^\n]+\n', "`n"
    Set-Content $path $c -Encoding UTF8 -NoNewline
    Write-Host "  Fixed: $path" -ForegroundColor Green
}

# ── main.dart: use_build_context_synchronously ────────────────────────────
$path = "lib\main.dart"
if (Test-Path $path) {
    $c = Get-Content $path -Raw -Encoding UTF8
    # Wrap Navigator.pushNamed setelah async gap dengan mounted check
    $c = $c -replace '(await \w+[^\n]+\n\s*)(Navigator\.',
        '$1if (!mounted) return;`n      Navigator.'
    Set-Content $path $c -Encoding UTF8 -NoNewline
    Write-Host "  Fixed: $path" -ForegroundColor Green
}

# ── pubspec.yaml: buat folder assets yang hilang ──────────────────────────
Write-Host ""
Write-Host "Creating missing asset directories..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path "assets\images" | Out-Null
New-Item -ItemType Directory -Force -Path "assets\fonts"  | Out-Null
Write-Host "  Created: assets\images\" -ForegroundColor Green
Write-Host "  Created: assets\fonts\"  -ForegroundColor Green

Write-Host ""
Write-Host "Done! Run 'flutter analyze' again to verify." -ForegroundColor Yellow
