# Perbaikan Final — Laporan & Cetak

## Yang diperbaiki

1. **Laporan tidak lagi terkunci pada Agustus 2026**
   - Bulan laporan dibuat otomatis dari tanggal transaksi yang benar-benar ada di Supabase.
   - Pilihan `Semua Periode` ditambahkan.
   - Setelah data selesai dimuat, laporan otomatis memilih periode transaksi terbaru.

2. **Normalisasi tanggal**
   - Mendukung `YYYY-MM-DD`.
   - Mendukung `DD/MM/YYYY` dan `DD-MM-YYYY`.
   - Transaksi bulan yang dipilih masuk ke laporan sesuai bulan kalendernya.

3. **Jenis laporan**
   - BKU: pemasukan + pengeluaran.
   - Rekapitulasi Pemasukan: hanya pemasukan.
   - Rekapitulasi Pengeluaran: hanya pengeluaran.
   - Saldo & Posisi Kas: ringkasan saldo.
   - Pertanggungjawaban Bulanan: transaksi periode.
   - Infaq / Pembayaran Siswa: transaksi pembayaran siswa/infaq dan filter kelas.

4. **Cetak dokumen A4**
   - Toolbar/filter/sidebar/navbar tidak ikut tercetak.
   - Preview laporan dicetak sebagai dokumen A4.
   - Header tabel diulang pada halaman berikutnya.
   - Baris tabel dijaga agar tidak terpotong.
   - Blok tanda tangan dijaga tetap utuh.
   - Layout print tidak lagi bergantung pada `flex + justify-between` yang dapat membuat halaman cetak tidak stabil.
   - Tanggal tanda tangan memakai tanggal saat dokumen dicetak.

5. **Logo**
   - Validasi PNG/JPG/JPEG/WEBP/SVG.
   - Maksimal 2 MB.
   - Upload menggunakan Supabase Storage bucket `logos`.
   - URL logo diverifikasi kembali setelah disimpan.
   - Hapus logo sekarang ikut menyimpan perubahan ke database.

6. **Pemasukan**
   - Error pembacaan pemasukan dari Supabase dicatat di console sehingga kegagalan query tidak lagi diam-diam.

## SQL

Gunakan:

`supabase/repair_laporan_dan_print.sql`

Script ini bersifat **additive/non-destructive**:
- tidak `DROP TABLE`;
- tidak menghapus pemasukan/pengeluaran;
- memastikan tabel/kolom penting tersedia;
- membuat index tanggal;
- memperbaiki RLS dasar;
- membuat bucket `logos` dan `bukti-pengeluaran` jika belum ada;
- memasang policy Storage.

## Urutan aman

1. Backup database jika ini sudah berisi data produksi.
2. Pastikan Auth user sudah login.
3. Jalankan `supabase/migration.sql` **hanya jika database belum pernah dibuat**.
4. Jalankan `supabase/migration_periode_pembukuan.sql` / `supabase/cutoff_migration.sql` sesuai kondisi database yang sudah ada.
5. Jalankan `supabase/repair_laporan_dan_print.sql`.
6. Jalankan aplikasi.
7. Masuk ke **Pemasukan**, simpan satu transaksi.
8. Buka **Laporan**.
9. Pilih `Rekapitulasi Pemasukan` atau `Buku Kas Umum (BKU)`.
10. Pastikan bulan transaksi muncul otomatis.
11. Klik **Cetak Dokumen (A4)**.

> Jangan menjalankan `src/lib/supabaseSql.ts` sebagai migrasi produksi tanpa backup karena skrip lama di file tersebut masih mengandung `DROP TABLE`.
