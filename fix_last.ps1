# fix_last.ps1
$path = "lib\main.dart"
$c = Get-Content $path -Raw -Encoding UTF8

# Fix: Future.delayed callback yang pakai Navigator.pop(context) tanpa mounted check
$c = $c -replace `
    'Future\.delayed\(const Duration\(seconds: 1\), \(\) \{\s*\n\s*if \(mounted\) Navigator\.pop\(context\);\s*\n\s*\}\);', `
    'Future.delayed(const Duration(seconds: 1), () {
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  });'

Set-Content $path $c -Encoding UTF8 -NoNewline
Write-Host "Fixed main.dart line 468" -ForegroundColor Green
