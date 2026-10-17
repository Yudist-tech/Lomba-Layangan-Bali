-- =====================================================================
-- CEK BUKTI (versi 1.0)
-- Jalankan SETELAH bukti-mirip.sql & bukti-selesai.sql. Aman dijalankan ulang.
--
-- Filter "Bukti Transfer Sama" & "Bukti Transfer Mirip" digabung menjadi satu
-- filter "Cek Bukti" dengan tingkat keyakinan (Pasti sama / Sangat mungkin /
-- Perlu dicek / Bayar gabungan). Yang ditambahkan di database:
--   1. hasil baca bukti: No. Referensi transaksi & 4 angka terakhir rekening pengirim
--   2. hasil pengecekan panitia: "sah" atau "bermasalah"
-- Data lama tidak diubah. Bukti yang sudah pernah dibaca akan dibaca ulang sekali
-- secara otomatis oleh dashboard untuk mengisi kolom baru.
-- =====================================================================

-- 1) hasil baca bukti
alter table public.lomba_bukti_baca add column if not exists ref   text;          -- No. Referensi / ID transaksi
alter table public.lomba_bukti_baca add column if not exists rek4  text;          -- 4 angka terakhir rekening pengirim
alter table public.lomba_bukti_baca add column if not exists versi smallint not null default 1;   -- versi pembaca (2 = ada ref & rek4)
create index if not exists lomba_bukti_baca_ref_idx on public.lomba_bukti_baca (event_id, ref) where ref is not null;

-- 2) hasil pengecekan: jenis baru "cek" + kolom hasil
alter table public.lomba_bukti_selesai drop constraint if exists lomba_bukti_selesai_jenis_check;
alter table public.lomba_bukti_selesai add constraint lomba_bukti_selesai_jenis_check check (jenis in ('sama', 'mirip', 'cek'));
alter table public.lomba_bukti_selesai add column if not exists hasil text;
alter table public.lomba_bukti_selesai drop constraint if exists lomba_bukti_selesai_hasil_check;
alter table public.lomba_bukti_selesai add constraint lomba_bukti_selesai_hasil_check check (hasil is null or hasil in ('sah', 'bermasalah'));

-- Pemeriksaan
select '✅ Hasil baca bukti: No. Referensi & rekening pengirim siap' as hasil
where exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'lomba_bukti_baca' and column_name = 'rek4')
union all
select '✅ Hasil pengecekan Sah / Bermasalah siap'
where exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'lomba_bukti_selesai' and column_name = 'hasil');
