-- =====================================================================
-- BUKTI MIRIP — hasil pembacaan gambar bukti transfer (versi 1.0)
-- Jalankan SETELAH multi-event.sql. Aman dijalankan ulang (idempotent).
--
-- Dashboard panitia membaca tulisan di setiap gambar bukti transfer (nominal,
-- waktu, nama pengirim). Hasilnya disimpan di tabel ini supaya setiap gambar
-- cukup dibaca sekali saja.
-- Tidak mengubah data pendaftaran yang sudah ada.
-- =====================================================================

create table if not exists public.lomba_bukti_baca (
  pendaftaran_id uuid primary key references public.lomba_pendaftaran(id) on delete cascade,
  event_id       bigint not null references public.lomba_event(id) on delete cascade,
  bukti_path     text,                      -- gambar yang dibaca (bila bukti diganti, dibaca ulang)
  nominal        bigint,                    -- nominal yang terbaca di gambar (rupiah)
  waktu          timestamp,                 -- tanggal & jam yang terbaca di gambar (jam lokal)
  nama           text,                      -- nama pengirim yang terbaca di gambar
  gagal          boolean not null default false,  -- tulisan tidak terbaca
  dibaca_at      timestamptz not null default now()
);
create index if not exists lomba_bukti_baca_event_idx on public.lomba_bukti_baca (event_id);

alter table public.lomba_bukti_baca enable row level security;
drop policy if exists lomba_admin_kelola on public.lomba_bukti_baca;
create policy lomba_admin_kelola on public.lomba_bukti_baca for all to authenticated
  using ((select public.lomba_boleh_event(event_id)))
  with check ((select public.lomba_boleh_event(event_id)));

revoke all on table public.lomba_bukti_baca from anon;
grant select, insert, update, delete on table public.lomba_bukti_baca to authenticated;
grant select, insert, update, delete on table public.lomba_bukti_baca to service_role;

-- Pemeriksaan
select '✅ Tabel lomba_bukti_baca siap' as hasil
where exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'lomba_bukti_baca')
union all
select '✅ Hak akses panitia per event aktif'
where exists (select 1 from pg_policies where tablename = 'lomba_bukti_baca' and policyname = 'lomba_admin_kelola');
