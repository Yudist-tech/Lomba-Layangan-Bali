-- =====================================================================
-- CADANGAN DATA SEBELUM FITUR CEK NAMA PENERIMA
-- Jalankan SEBELUM cek-penerima.sql: SQL Editor → paste seluruh isi → Run.
-- Boleh dijalankan ulang (cadangan lama ditimpa dengan data terbaru).
--
-- Menyalin SEMUA tabel lomba_* ke skema terpisah "cadangan_sebelum_cek_penerima",
-- ditambah teks SEMUA fungsi lomba_* (supaya fungsi yang nanti diubah bisa
-- dikembalikan persis seperti sekarang). Data asli TIDAK diubah atau dihapus.
-- Salinan hanya bisa dibuka dari dashboard Supabase (tanpa akses publik).
--
-- File di Storage (bukti transfer, logo, flyer) tidak disalin karena
-- fitur cek penerima tidak mengubah atau menghapus file apa pun.
-- =====================================================================

create schema if not exists cadangan_sebelum_cek_penerima;
revoke all on schema cadangan_sebelum_cek_penerima from public, anon, authenticated;

do $$
declare
  t text;
begin
  for t in select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
            where n.nspname = 'public' and c.relkind = 'r' and c.relname like 'lomba\_%' order by 1
  loop
    execute format('drop table if exists cadangan_sebelum_cek_penerima.%I', t);
    execute format('create table cadangan_sebelum_cek_penerima.%I as table public.%I', t, t);
  end loop;
end $$;

-- teks semua fungsi lomba_* (untuk dikembalikan bila perlu)
drop table if exists cadangan_sebelum_cek_penerima._fungsi;
create table cadangan_sebelum_cek_penerima._fungsi as
  select p.proname as nama, pg_get_function_identity_arguments(p.oid) as argumen, pg_get_functiondef(p.oid) as definisi, now() as dicadangkan_at
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname like 'lomba\_%' and p.prokind = 'f';

-- Ringkasan: jumlah baris asli vs cadangan (harus sama di setiap baris)
with t as (
  select table_name as tabel,
         (xpath('/row/c/text()', query_to_xml(format('select count(*) as c from public.%I', table_name), false, true, '')))[1]::text::bigint as asli,
         (xpath('/row/c/text()', query_to_xml(format('select count(*) as c from cadangan_sebelum_cek_penerima.%I', table_name), false, true, '')))[1]::text::bigint as cadangan
    from information_schema.tables
   where table_schema = 'cadangan_sebelum_cek_penerima' and table_name like 'lomba\_%'
)
select tabel, asli, cadangan, case when asli = cadangan then '✅' else '❌' end as cocok from t
union all
select '(fungsi lomba_*)', null, (select count(*) from cadangan_sebelum_cek_penerima._fungsi),
       case when exists (select 1 from cadangan_sebelum_cek_penerima._fungsi) then '✅' else '❌' end
order by 1;
