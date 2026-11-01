-- =====================================================================
-- CEK NAMA PENERIMA DI BUKTI TRANSFER
-- Jalankan SETELAH cadangan-sebelum-cek-penerima.sql: SQL Editor → paste → Run.
-- Boleh dijalankan ulang.
--
-- Menambah 1 kolom "penerima" (nama penerima yang terbaca di foto bukti)
-- pada tabel hasil baca bukti. Data lain tidak diubah.
-- Setelah dijalankan: buka dashboard panitia → Cek Bukti → "Periksa bukti"
-- supaya semua bukti dibaca ulang sekali dan nama penerimanya ikut dicek.
-- =====================================================================

alter table public.lomba_bukti_baca add column if not exists penerima text;

notify pgrst, 'reload schema';

select case when exists (select 1 from information_schema.columns
                          where table_schema = 'public' and table_name = 'lomba_bukti_baca' and column_name = 'penerima')
            then '✅ kolom penerima siap' else '❌ kolom penerima belum ada' end as hasil;
