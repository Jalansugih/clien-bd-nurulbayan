-- ================================================================
-- RAJAKAS / BD-NURULBAYAN
-- REPAIR AMAN: LAPORAN, TRANSAKSI, PERIODE & STORAGE
-- ================================================================
-- Tujuan:
-- 1. Memastikan struktur tabel yang dipakai frontend tersedia.
-- 2. Memastikan data pemasukan dapat dibaca user login.
-- 3. Menambahkan index tanggal untuk laporan.
-- 4. Membuat bucket Storage "logos" dan "bukti-pengeluaran" jika belum ada.
-- 5. Menyiapkan policy Storage tanpa menghapus data transaksi.
--
-- PENTING: Script ini TIDAK DROP TABLE dan TIDAK DELETE pemasukan/pengeluaran.
-- Jalankan di Supabase SQL Editor sebagai project owner/admin.
-- ================================================================

BEGIN;

-- ------------------------------------------------
-- A. KONFIGURASI LEMBAGA
-- ------------------------------------------------
CREATE TABLE IF NOT EXISTS public.konfigurasi_lembaga (
  id BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (id = TRUE),
  nama_lembaga VARCHAR(150) NOT NULL DEFAULT '',
  jenis_lembaga VARCHAR(30) NOT NULL DEFAULT 'SD',
  logo_url TEXT,
  saldo_awal NUMERIC(15,2) NOT NULL DEFAULT 0,
  npsn VARCHAR(30),
  alamat TEXT,
  kontak VARCHAR(50),
  website VARCHAR(150),
  tahun_ajaran VARCHAR(20) NOT NULL DEFAULT '2025/2026',
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  updated_by UUID
);

ALTER TABLE public.konfigurasi_lembaga
  ADD COLUMN IF NOT EXISTS tahun_ajaran VARCHAR(20) NOT NULL DEFAULT '2025/2026',
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS updated_by UUID;

INSERT INTO public.konfigurasi_lembaga (id)
VALUES (TRUE)
ON CONFLICT (id) DO NOTHING;

-- ------------------------------------------------
-- B. TRANSAKSI PEMASUKAN / PENGELUARAN
-- ------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pemasukan (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  no_bukti VARCHAR(50) NOT NULL,
  tanggal DATE NOT NULL,
  sumber VARCHAR(50) NOT NULL,
  sub VARCHAR(100) NOT NULL,
  nominal NUMERIC(15,2) NOT NULL CHECK (nominal > 0),
  keterangan TEXT NOT NULL,
  status VARCHAR(20) DEFAULT 'Selesai',
  siswa_id UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID
);

CREATE TABLE IF NOT EXISTS public.pengeluaran (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  no_bukti VARCHAR(50) NOT NULL,
  tanggal DATE NOT NULL,
  kategori VARCHAR(100) NOT NULL,
  nominal NUMERIC(15,2) NOT NULL CHECK (nominal > 0),
  keterangan TEXT NOT NULL,
  status VARCHAR(20) DEFAULT 'Terbayar',
  bukti_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID
);

ALTER TABLE public.pemasukan
  ADD COLUMN IF NOT EXISTS siswa_id UUID,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS created_by UUID,
  ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'Selesai';

ALTER TABLE public.pengeluaran
  ADD COLUMN IF NOT EXISTS bukti_url TEXT,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS created_by UUID,
  ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'Terbayar';

CREATE INDEX IF NOT EXISTS idx_pemasukan_tanggal
  ON public.pemasukan (tanggal DESC);

CREATE INDEX IF NOT EXISTS idx_pengeluaran_tanggal
  ON public.pengeluaran (tanggal DESC);

-- ------------------------------------------------
-- C. RLS TRANSAKSI
-- ------------------------------------------------
ALTER TABLE public.pemasukan ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pengeluaran ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.konfigurasi_lembaga ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.pemasukan, public.pengeluaran, public.konfigurasi_lembaga
  TO authenticated;

DROP POLICY IF EXISTS "Hanya user login - pemasukan" ON public.pemasukan;
CREATE POLICY "Hanya user login - pemasukan"
  ON public.pemasukan
  FOR ALL
  TO authenticated
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Hanya user login - pengeluaran" ON public.pengeluaran;
CREATE POLICY "Hanya user login - pengeluaran"
  ON public.pengeluaran
  FOR ALL
  TO authenticated
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Hanya user login - konfigurasi_lembaga" ON public.konfigurasi_lembaga;
CREATE POLICY "Hanya user login - konfigurasi_lembaga"
  ON public.konfigurasi_lembaga
  FOR ALL
  TO authenticated
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');

-- ------------------------------------------------
-- D. PERIODE PEMBUKUAN
-- ------------------------------------------------
CREATE TABLE IF NOT EXISTS public.periode_pembukuan (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  nama_periode VARCHAR(50) NOT NULL,
  tahun_ajaran VARCHAR(20) NOT NULL DEFAULT '2025/2026',
  tanggal_mulai DATE NOT NULL,
  tanggal_akhir DATE,
  saldo_awal NUMERIC(15,2) NOT NULL DEFAULT 0 CHECK (saldo_awal >= 0),
  saldo_akhir NUMERIC(15,2),
  status VARCHAR(10) NOT NULL DEFAULT 'AKTIF' CHECK (status IN ('AKTIF','DITUTUP')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID,
  closed_at TIMESTAMPTZ,
  closed_by UUID
);

ALTER TABLE public.periode_pembukuan
  ADD COLUMN IF NOT EXISTS tahun_ajaran VARCHAR(20) NOT NULL DEFAULT '2025/2026',
  ADD COLUMN IF NOT EXISTS tanggal_akhir DATE,
  ADD COLUMN IF NOT EXISTS saldo_awal NUMERIC(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS saldo_akhir NUMERIC(15,2),
  ADD COLUMN IF NOT EXISTS status VARCHAR(10) NOT NULL DEFAULT 'AKTIF',
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS created_by UUID,
  ADD COLUMN IF NOT EXISTS closed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS closed_by UUID;

CREATE INDEX IF NOT EXISTS idx_periode_pembukuan_tanggal
  ON public.periode_pembukuan (tanggal_mulai DESC, tanggal_akhir DESC);

CREATE UNIQUE INDEX IF NOT EXISTS ux_periode_pembukuan_satu_aktif
  ON public.periode_pembukuan (status)
  WHERE status = 'AKTIF';

ALTER TABLE public.periode_pembukuan ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.periode_pembukuan TO authenticated;

DROP POLICY IF EXISTS "Periode pembukuan - user login" ON public.periode_pembukuan;
CREATE POLICY "Periode pembukuan - user login"
  ON public.periode_pembukuan
  FOR ALL
  TO authenticated
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');

-- ------------------------------------------------
-- E. STORAGE BUCKET
-- ------------------------------------------------
-- Public hanya untuk file yang memang dimaksudkan tampil sebagai logo/bukti.
INSERT INTO storage.buckets (id, name, public)
VALUES ('logos', 'logos', TRUE)
ON CONFLICT (id) DO UPDATE SET public = TRUE;

INSERT INTO storage.buckets (id, name, public)
VALUES ('bukti-pengeluaran', 'bukti-pengeluaran', TRUE)
ON CONFLICT (id) DO UPDATE SET public = TRUE;

DROP POLICY IF EXISTS "Logo - baca publik" ON storage.objects;
CREATE POLICY "Logo - baca publik"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'logos');

DROP POLICY IF EXISTS "Logo - upload user login" ON storage.objects;
CREATE POLICY "Logo - upload user login"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'logos' AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Logo - update user login" ON storage.objects;
CREATE POLICY "Logo - update user login"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (bucket_id = 'logos' AND auth.role() = 'authenticated')
  WITH CHECK (bucket_id = 'logos' AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Logo - delete user login" ON storage.objects;
CREATE POLICY "Logo - delete user login"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'logos' AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Bukti Pengeluaran - baca publik" ON storage.objects;
CREATE POLICY "Bukti Pengeluaran - baca publik"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'bukti-pengeluaran');

DROP POLICY IF EXISTS "Bukti Pengeluaran - upload user login" ON storage.objects;
CREATE POLICY "Bukti Pengeluaran - upload user login"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'bukti-pengeluaran' AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Bukti Pengeluaran - update user login" ON storage.objects;
CREATE POLICY "Bukti Pengeluaran - update user login"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (bucket_id = 'bukti-pengeluaran' AND auth.role() = 'authenticated')
  WITH CHECK (bucket_id = 'bukti-pengeluaran' AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Bukti Pengeluaran - delete user login" ON storage.objects;
CREATE POLICY "Bukti Pengeluaran - delete user login"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'bukti-pengeluaran' AND auth.role() = 'authenticated');

COMMIT;

-- ================================================================
-- F. DIAGNOSTIK SETELAH REPAIR
-- Jalankan blok SELECT ini terpisah bila ingin melihat hasilnya.
-- ================================================================

-- 1) Harus menghasilkan minimal 1 baris:
SELECT id, nama_lembaga, tahun_ajaran, saldo_awal, logo_url
FROM public.konfigurasi_lembaga
WHERE id = TRUE;

-- 2) Data pemasukan terbaru yang akan dibaca menu Laporan:
SELECT id, no_bukti, tanggal, sumber, sub, nominal, keterangan, status
FROM public.pemasukan
ORDER BY tanggal DESC, created_at DESC
LIMIT 50;

-- 3) Periode aktif:
SELECT id, nama_periode, tahun_ajaran, tanggal_mulai, tanggal_akhir, saldo_awal, saldo_akhir, status
FROM public.periode_pembukuan
ORDER BY tanggal_mulai DESC;

-- 4) Pastikan bucket ada:
SELECT id, name, public
FROM storage.buckets
WHERE id IN ('logos', 'bukti-pengeluaran');

-- 5) Pastikan tanggal transaksi terindeks untuk laporan:
SELECT indexname
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname IN ('idx_pemasukan_tanggal', 'idx_pengeluaran_tanggal');
