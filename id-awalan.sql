-- =====================================================================
-- ID PANITIA: AWALAN I / Ni KADANG IKUT (versi 1.0)
-- Jalankan SETELAH login-nama.sql. Aman dijalankan ulang.
--
-- Huruf awalan nama Bali "I" atau "Ni" sekarang ikut dipakai di ID secara acak
-- (± separuh kesempatan), sehingga ID lebih beragam. Contoh:
--   "I Made Darma Wiguna Artha" → Mdwia587  atau  Imdwa587
-- ID yang sudah ada TIDAK berubah. Hanya fungsi pembuat huruf yang diganti.
-- =====================================================================

create or replace function public.lomba_huruf_nama(p_nama text)
returns text
language plpgsql
volatile
set search_path = public
as $$
declare
  w     text[];
  n     int;
  idx   int[];
  hasil text;
begin
  w := array_remove(regexp_split_to_array(lower(regexp_replace(translate(coalesce(p_nama, ''),
         'ÁÀÂÄÃÉÈÊËÍÌÎÏÓÒÔÖÕÚÙÛÜáàâäãéèêëíìîïóòôöõúùûü', 'AAAAAEEEEIIIIOOOOOUUUUaaaaaeeeeiiiiooooouuuu'),
         '[^A-Za-z ]', ' ', 'g')), '\s+'), '');
  n := coalesce(array_length(w, 1), 0);
  if n > 1 and w[1] in ('i', 'ni') and random() < 0.5 then
    w := w[2:];
    n := n - 1;
  end if;
  if n = 0 then
    hasil := '';
  else
    -- kata yang dipakai: semua (≤ 5 kata), atau kata pertama + 3 kata tengah acak + kata terakhir
    if n <= 5 then
      idx := array(select generate_series(1, n));
    else
      idx := array[1] || array(select i from (select i from generate_series(2, n - 1) i order by random() limit 3) x order by i) || array[n];
    end if;
    with kata as (
      select u.urut, w[u.k] as t from unnest(idx) with ordinality as u(k, urut)
    ), awal as (
      select urut, 1 as pos from kata
    ), tambah as (
      select urut, pos from kata, generate_series(2, length(t)) as pos
       order by random() limit greatest(0, 5 - (select count(*) from kata))
    )
    select string_agg(substr(k.t, x.pos, 1), '' order by x.urut, x.pos) into hasil
      from (select * from awal union all select * from tambah) x join kata k on k.urut = x.urut;
  end if;
  hasil := coalesce(hasil, '');
  while length(hasil) < 5 loop
    hasil := hasil || chr(97 + floor(random() * 26)::int);
  end loop;
  return left(hasil, 5);
end;
$$;

revoke all on function public.lomba_huruf_nama(text) from public, anon, authenticated;

-- Pemeriksaan: buat 20 contoh, harus ada yang diawali "i" dan yang tidak
select '✅ Awalan I/Ni kadang ikut: ' || string_agg(distinct initcap(h), ', ') as hasil
from (select public.lomba_huruf_nama('I Made Darma Wiguna Artha') as h from generate_series(1, 20)) x
having bool_or(h like 'i%') and bool_or(h not like 'i%');
