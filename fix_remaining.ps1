# fix_remaining.ps1
# Jalankan dari root folder project: .\fix_remaining.ps1

Write-Host "Fixing 3 remaining issues..." -ForegroundColor Cyan

# ── 1. receipt_screen.dart: unused import 'dart:typed_data' ───────────────
$path = "lib\screens\receipt_screen.dart"
if (Test-Path $path) {
    $c = Get-Content $path -Raw -Encoding UTF8
    $c = $c -replace "import 'dart:typed_data';\r?\n", ""
    Set-Content $path $c -Encoding UTF8 -NoNewline
    Write-Host "  Fixed: removed unused import in $path" -ForegroundColor Green
}

# ── 2. auth_provider.dart: unnecessary non-null assertion (!) ─────────────
$path = "lib\providers\auth_provider.dart"
if (Test-Path $path) {
    $c = Get-Content $path -Raw -Encoding UTF8
    # Ganti resultList!.first → resultList.first (receiver can't be null disini)
    $c = $c -replace 'resultList!\.first', 'resultList.first'
    Set-Content $path $c -Encoding UTF8 -NoNewline
    Write-Host "  Fixed: removed unnecessary ! in $path" -ForegroundColor Green
}

# ── 3. main.dart: BuildContext across async gap (line 469) ────────────────
# Tambah mounted check sebelum ScaffoldMessenger
$path = "lib\main.dart"
if (Test-Path $path) {
    $c = Get-Content $path -Raw -Encoding UTF8

    # Pattern: setelah await ... ada ScaffoldMessenger.of(context)
    # Tambah if (!mounted) return; sebelumnya
    $c = $c -replace '(\}\s*\n)(\s*ScaffoldMessenger\.of\(context\))',
        '$1      if (!mounted) return;`n$2'

    Set-Content $path $c -Encoding UTF8 -NoNewline
    Write-Host "  Fixed: added mounted check in $path" -ForegroundColor Green
}

Write-Host ""
Write-Host "Done! Run 'flutter analyze' to verify." -ForegroundColor Yellow
