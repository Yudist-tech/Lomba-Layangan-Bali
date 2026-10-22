-- =====================================================================
-- RESET NILAI PER SERI (versi 1.0)
-- Jalankan SETELAH juara.sql dan upload-form.sql. Aman dijalankan ulang.
-- Hanya MENAMBAH kolom (tidak mengubah / menghapus data lama).
--
-- 1) lomba_form_upload.seri_id : seri terbang yang dipilih panitia saat upload form
-- 2) lomba_nilai.upload_id     : nilai ini masuk dari upload form yang mana
--
-- Dipakai oleh "Pengaturan nilai → Reset nilai": reset Seri X menghapus semua
-- nilai yang di-upload dengan pilihan Seri X (termasuk layangan yang terdaftar
-- di seri lain), ditambah nilai ketikan manual untuk layangan yang terdaftar di Seri X.
-- =====================================================================

alter table public.lomba_form_upload add column if not exists seri_id bigint references public.lomba_seri(id) on delete set null;
alter table public.lomba_nilai add column if not exists upload_id bigint references public.lomba_form_upload(id) on delete set null;
create index if not exists lomba_nilai_upload_idx on public.lomba_nilai (upload_id);

-- Pemeriksaan
select '✅ Seri upload siap' as hasil
where exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'lomba_form_upload' and column_name = 'seri_id')
union all
select '✅ Asal upload nilai siap'
where exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'lomba_nilai' and column_name = 'upload_id');
