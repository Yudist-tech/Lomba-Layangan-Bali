-- =====================================================================
-- NOMOR LAYANGAN MINIMAL 2 ANGKA (versi 1.0)
-- Jalankan SETELAH multi-event.sql. Aman dijalankan ulang (idempotent).
--
-- Semua nomor layangan ditulis minimal 2 angka: 1 → 01, 2 → 02 … 9 → 09.
-- Nomor 10 ke atas tidak berubah. Berlaku untuk semua jenis & semua event,
-- termasuk nomor peserta yang SUDAH terdaftar (ditulis ulang otomatis).
-- Jenis yang memakai 3 angka (001, 002 …) tetap 3 angka.
-- =====================================================================

-- 1) setiap jenis (baru maupun lama) minimal 2 angka — dijaga database
create or replace function public.lomba_trg_jenis_digit()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.nomor_digit := greatest(coalesce(new.nomor_digit, 0), 2);
  return new;
end;
$$;
drop trigger if exists lomba_jenis_digit_biu on public.lomba_jenis;
create trigger lomba_jenis_digit_biu before insert or update on public.lomba_jenis
  for each row execute function public.lomba_trg_jenis_digit();

alter table public.lomba_jenis alter column nomor_digit set default 2;

-- 2) jenis yang sudah ada → 2 angka; nomor peserta lama ikut ditulis ulang
--    (oleh trigger lomba_jenis_nomor_au dari multi-event.sql)
update public.lomba_jenis set nomor_digit = 2 where coalesce(nomor_digit, 0) < 2;

-- 3) jaga-jaga: nomor 1 angka yang masih tersisa
update public.lomba_pendaftaran p
   set nomor_layangan = public.lomba_rapikan_nomor(p.nomor_layangan, greatest(coalesce(j.nomor_digit, 0), 2))
  from public.lomba_jenis j
 where j.event_id = p.event_id and j.kode = p.jenis
   and p.nomor_layangan ~ '^[0-9]$';

revoke all on function public.lomba_trg_jenis_digit() from public, anon, authenticated;

-- Pemeriksaan
select '✅ Nomor layangan minimal 2 angka aktif' as hasil
where exists (select 1 from pg_trigger where tgname = 'lomba_jenis_digit_biu')
union all
select '✅ Semua nomor peserta sudah 2 angka'
where not exists (select 1 from public.lomba_pendaftaran where nomor_layangan ~ '^[0-9]$');
