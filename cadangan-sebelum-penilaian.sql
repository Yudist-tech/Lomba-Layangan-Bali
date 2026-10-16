-- =====================================================================
-- CADANGAN DATA SEBELUM FITUR PENILAIAN & JUARA
-- Jalankan SEBELUM juara.sql: SQL Editor → paste seluruh isi → Run.
-- Boleh dijalankan ulang (cadangan lama ditimpa dengan data terbaru).
--
-- Menyalin SEMUA tabel lomba_* ke skema terpisah "cadangan_sebelum_penilaian",
-- ditambah teks fungsi lomba_ringkas_event (satu-satunya fungsi lama yang
-- diganti oleh juara.sql). Data asli TIDAK diubah atau dihapus.
-- Salinan hanya bisa dibuka dari dashboard Supabase (tanpa akses publik).
--
-- File di Storage (bukti transfer, logo, flyer) tidak disalin karena
-- juara.sql tidak mengubah atau menghapus file apa pun.
-- =====================================================================

create schema if not exists cadangan_sebelum_penilaian;
revoke all on schema cadangan_sebelum_penilaian from public, anon, authenticated;

do $$
declare
  t text;
begin
  for t in select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
            where n.nspname = 'public' and c.relkind = 'r' and c.relname like 'lomba\_%' order by 1
  loop
    execute format('drop table if exists cadangan_sebelum_penilaian.%I', t);
    execute format('create table cadangan_sebelum_penilaian.%I as table public.%I', t, t);
  end loop;
end $$;

-- teks fungsi yang akan diganti juara.sql (untuk dikembalikan bila perlu)
drop table if exists cadangan_sebelum_penilaian._fungsi;
create table cadangan_sebelum_penilaian._fungsi as
  select p.proname as nama, pg_get_functiondef(p.oid) as definisi, now() as dicadangkan_at
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname in ('lomba_ringkas_event');

-- Ringkasan: jumlah baris asli vs cadangan (harus sama di setiap baris)
with t as (
  select table_name as tabel,
         (xpath('/row/c/text()', query_to_xml(format('select count(*) as c from public.%I', table_name), false, true, '')))[1]::text::bigint as asli,
         (xpath('/row/c/text()', query_to_xml(format('select count(*) as c from cadangan_sebelum_penilaian.%I', table_name), false, true, '')))[1]::text::bigint as cadangan
    from information_schema.tables
   where table_schema = 'cadangan_sebelum_penilaian' and table_name like 'lomba\_%'
)
select tabel, asli, cadangan, case when asli = cadangan then '✅' else '❌' end as cocok from t
union all
select '(fungsi lomba_ringkas_event)', null, (select count(*) from cadangan_sebelum_penilaian._fungsi),
       case when exists (select 1 from cadangan_sebelum_penilaian._fungsi) then '✅' else '❌' end
order by 1;
