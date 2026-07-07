# PANDUAN PENGUJIAN APLIKASI (DOSEN / EVALUATOR)
## MAKARYA ERP - Sistem Manajemen Terpadu Toko Buku & Coffee Shop

Panduan singkat ini dibuat khusus untuk mempermudah Bapak/Ibu Dosen dalam menguji fungsionalitas utama aplikasi Makarya ERP, mulai dari login hingga simulasi transaksi lengkap.

---

## 1. LOGIN SISTEM
Untuk menguji aplikasi, gunakan salah satu kredensial berikut:

**Akses Kasir (POS):**
- **ID Karyawan:** `EMP-100`
- **PIN:** `2345`

**Akses Manajer (Dashboard & HR):**
*(Jika Bapak/Ibu ingin menguji laporan keuangan dan pengelolaan karyawan)*
- **ID Karyawan:** `EMP-001`
- **PIN:** *(Silakan minta PIN Manajer ke mahasiswa bersangkutan)*

> **Catatan:** Setelah login, sistem akan otomatis mengenali role (jabatan) Anda dan menampilkan menu yang sesuai.

---

## 2. SKENARIO PENGUJIAN 1: TRANSAKSI KASIR (POS)
Skenario ini mensimulasikan ada pelanggan yang membeli minuman kopi dan buku fisik.

1. Login menggunakan akun Kasir (`EMP-100`).
2. Di menu utama sebelah kiri, pastikan Anda berada di layar **POS**.
3. **Pesan Kopi:** 
   - Klik kategori **COFFEE**.
   - Tap salah satu menu kopi (misal: *Makarya Signature Espresso*).
   - Menu akan masuk ke keranjang di panel kanan.
4. **Pesan Buku (Simulasi Barcode):**
   - Klik tombol ikon **Kamera / Barcode** di atas layar katalog.
   - Karena ini emulator/web, sistem akan mensimulasikan pembacaan barcode buku secara otomatis.
   - Buku (misal: novel *Pulang* karya Tere Liye) akan masuk ke keranjang.
5. **Cek Fitur Promo Otomatis:**
   - Perhatikan di panel keranjang, sistem akan mendeteksi pembelian Kopi + Buku secara bersamaan dan **otomatis memberikan diskon Bundle 10%**.
6. **Checkout:**
   - Tekan tombol hijau **Proses Pembayaran** di pojok kanan bawah.
   - Pilih metode `CASH`, ketik uang yang dibayarkan (misal: `150000`).
   - Klik **Selesaikan**. 
   - Sebuah popup struk transaksi (Receipt) yang dirancang khusus akan muncul. (Tekan 'Tutup & Transaksi Baru' untuk selesai).

---

## 3. SKENARIO PENGUJIAN 2: KITCHEN DISPLAY SYSTEM (KDS)
Sistem ini menggantikan kertas tiket pesanan di dapur. Pesanan kopi dari skenario 1 tadi akan langsung masuk ke layar Barista.

1. Login menggunakan akun Barista (atau jika masih di akun Kasir, tekan menu **KDS / Dapur** di navigasi kiri jika role mengizinkan).
2. Anda akan melihat **Tiket Pesanan** (berisi pesanan kopi tadi) dengan status `PENDING` (warna abu-abu) dan ada *Timer* waktu tunggu.
3. **Simulasi:**
   - Tekan tombol kuning **Tandai Siap (READY)** seolah minuman sudah selesai diracik.
   - Tekan tombol hijau **Selesaikan (DONE)** saat minuman diserahkan ke pelanggan.
   - *Di balik layar, sistem akan memotong stok bahan baku (biji kopi, susu, dll) secara otomatis di database.*

---

## 4. SKENARIO PENGUJIAN 3: DASHBOARD & ANALITIK (MANAJER)
Untuk melihat pencatatan Laba Bersih yang akurat (Net Profit).

1. Login menggunakan akun Manajer (`EMP-001`).
2. Masuk ke layar **Dashboard**.
3. Bapak/Ibu dapat melihat matriks canggih seperti:
   - **Net Margin:** Laba bersih setelah dikurangi HPP, operasional, dan bahan terbuang (wastage).
   - **Sales Mix:** Perbandingan pendapatan buku vs kafe.
   - **Peak Hours:** Jam tersibuk toko (Heatmap).
4. **Cek Laporan PDF:** 
   - Masuk ke menu **Financial Report / Analytics**.
   - Klik tombol *Export PDF* di pojok kanan atas untuk melihat hasil generate laporan keuangan berstandar profesional.

---

## 5. PENGECEKAN DATABASE (SUPABASE)
Aplikasi ini sudah terhubung ke *Cloud Database Supabase* secara *real-time*.
- Mahasiswa telah mengundang email Bapak/Ibu sebagai `Read-Only` member di Supabase.
- Silakan buka **[Supabase Dashboard](https://supabase.com/dashboard)** untuk memverifikasi struktur tabel (Terdapat lebih dari 20 tabel: `transactions`, `items`, `staff`, `wastage_logs`, dll).
- Bapak/Ibu dapat mengecek baris tabel `transactions` untuk memastikan pesanan yang baru saja diuji sudah tercatat di cloud database.

---
*Terima kasih telah meluangkan waktu untuk mengevaluasi aplikasi Makarya ERP.*
