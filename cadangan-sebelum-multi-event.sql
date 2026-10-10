-- =====================================================================
-- CADANGAN DATA SEBELUM MULTI-EVENT
-- Jalankan SEKALI di Supabase: SQL Editor → paste seluruh isi → Run.
--
-- Menyalin semua tabel lomba ke skema terpisah "cadangan_sebelum_multi_event".
-- Data asli TIDAK diubah atau dihapus. Salinan ini tidak bisa dibuka dari
-- halaman peserta (tidak ada akses publik), hanya dari dashboard Supabase.
--
-- File bukti transfer, logo, dan gambar latar di Storage tidak ikut disalin
-- di sini karena memang tidak akan diubah oleh pembaruan multi-event.
-- =====================================================================

create schema if not exists cadangan_sebelum_multi_event;
revoke all on schema cadangan_sebelum_multi_event from anon, authenticated;

do $$
declare
  t text;
begin
  foreach t in array array['lomba_admin', 'lomba_pengaturan', 'lomba_jenis', 'lomba_hari',
                           'lomba_sesi', 'lomba_seri', 'lomba_pendaftaran']
  loop
    if to_regclass('public.' || t) is not null then
      execute format('drop table if exists cadangan_sebelum_multi_event.%I', t);
      execute format('create table cadangan_sebelum_multi_event.%I as table public.%I', t, t);
    end if;
  end loop;
end $$;

-- Ringkasan: jumlah baris asli vs salinan (harus sama)
select 'lomba_pendaftaran' as tabel,
       (select count(*) from public.lomba_pendaftaran) as asli,
       (select count(*) from cadangan_sebelum_multi_event.lomba_pendaftaran) as cadangan
union all select 'lomba_seri', (select count(*) from public.lomba_seri), (select count(*) from cadangan_sebelum_multi_event.lomba_seri)
union all select 'lomba_jenis', (select count(*) from public.lomba_jenis), (select count(*) from cadangan_sebelum_multi_event.lomba_jenis)
union all select 'lomba_sesi', (select count(*) from public.lomba_sesi), (select count(*) from cadangan_sebelum_multi_event.lomba_sesi)
union all select 'lomba_hari', (select count(*) from public.lomba_hari), (select count(*) from cadangan_sebelum_multi_event.lomba_hari)
union all select 'lomba_pengaturan', (select count(*) from public.lomba_pengaturan), (select count(*) from cadangan_sebelum_multi_event.lomba_pengaturan)
union all select 'lomba_admin', (select count(*) from public.lomba_admin), (select count(*) from cadangan_sebelum_multi_event.lomba_admin);
