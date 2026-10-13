-- =====================================================================
-- ID PANITIA DARI NAMA LENGKAP (versi 1.0)
-- Jalankan SETELAH login-id.sql. Aman dijalankan ulang (idempotent).
--
-- Super admin cukup mengetik nama lengkap panitia; sistem membuat ID
-- 5 huruf dari setiap kata nama + 3 angka acak, mis. "I Made Darma Wiguna Artha" → Mdwia587.
-- Nama lengkap disimpan supaya tampil di daftar admin & di dashboard.
-- =====================================================================

create table if not exists public.lomba_panitia (
  email      text primary key,
  nama       text not null,
  created_at timestamptz not null default now()
);
alter table public.lomba_panitia enable row level security;
revoke all on table public.lomba_panitia from anon, authenticated;

-- 5 huruf dari nama, sesuai urutan nama: huruf awal SETIAP kata (awalan I / Ni dilewati);
-- bila kata < 5, sisanya huruf acak dari dalam nama (urutan tetap). Contoh:
-- "I Made Darma Wiguna Artha" → m d w (i) a → mdwia
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
  if n > 1 and w[1] in ('i', 'ni') then
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

-- 3 angka acak tanpa pola mudah (000, 111, 123, 321, …)
create or replace function public.lomba_angka_acak()
returns text
language plpgsql
volatile
set search_path = public
as $$
declare
  a text;
begin
  loop
    a := lpad(floor(random() * 1000)::int::text, 3, '0');
    exit when not (substr(a, 1, 1) = substr(a, 2, 1) and substr(a, 2, 1) = substr(a, 3, 1))
          and a not in ('012', '123', '234', '345', '456', '567', '678', '789', '890',
                        '098', '987', '876', '765', '654', '543', '432', '321', '210');
  end loop;
  return a;
end;
$$;

-- Buat akun panitia dari nama lengkap → ID unik + password, lalu beri akses event
create or replace function public.lomba_buat_akun_nama(p_event bigint, p_nama text, p_password text)
returns json
language plpgsql
security definer
set search_path = public, extensions, auth
as $$
declare
  v_nama  text := btrim(regexp_replace(coalesce(p_nama, ''), '\s+', ' ', 'g'));
  v_huruf text;
  v_id    text;
  v_coba  int := 0;
  r       json;
begin
  perform public.lomba_wajib_super();
  if length(v_nama) < 3 or v_nama !~ '[A-Za-z]' then
    raise exception 'NAMA_TIDAK_VALID';
  end if;
  loop
    v_coba := v_coba + 1;
    v_huruf := public.lomba_huruf_nama(v_nama);
    v_id := v_huruf || public.lomba_angka_acak();
    exit when not exists (select 1 from auth.users where lower(email) = public.lomba_email_id(v_id));
    if v_coba > 200 then
      raise exception 'ID_PENUH';
    end if;
  end loop;
  r := public.lomba_buat_akun_id(p_event, v_id, p_password);
  insert into public.lomba_panitia (email, nama) values (public.lomba_email_id(v_id), v_nama)
  on conflict (email) do update set nama = excluded.nama;
  return json_build_object('id', v_id, 'email', public.lomba_email_id(v_id), 'nama', v_nama, 'baru', true);
end;
$$;

-- Nama lengkap panitia: super admin melihat semua, panitia hanya namanya sendiri
create or replace function public.lomba_nama_panitia()
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if public.lomba_is_super() then
    return coalesce((select json_object_agg(email, nama) from public.lomba_panitia), '{}'::json);
  end if;
  return coalesce((select json_object_agg(email, nama) from public.lomba_panitia where email = public.lomba_email_saya()), '{}'::json);
end;
$$;

-- Ubah nama lengkap (super admin)
create or replace function public.lomba_ubah_nama_panitia(p_email text, p_nama text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_nama text := btrim(regexp_replace(coalesce(p_nama, ''), '\s+', ' ', 'g'));
begin
  perform public.lomba_wajib_super();
  if length(v_nama) < 3 then
    raise exception 'NAMA_TIDAK_VALID';
  end if;
  insert into public.lomba_panitia (email, nama) values (lower(btrim(p_email)), v_nama)
  on conflict (email) do update set nama = excluded.nama;
end;
$$;

revoke all on function public.lomba_huruf_nama(text) from public, anon, authenticated;
revoke all on function public.lomba_angka_acak() from public, anon, authenticated;
revoke all on function public.lomba_buat_akun_nama(bigint, text, text) from public, anon;
revoke all on function public.lomba_nama_panitia() from public, anon;
revoke all on function public.lomba_ubah_nama_panitia(text, text) from public, anon;
grant execute on function public.lomba_buat_akun_nama(bigint, text, text) to authenticated;
grant execute on function public.lomba_nama_panitia() to authenticated;
grant execute on function public.lomba_ubah_nama_panitia(text, text) to authenticated;

-- Pemeriksaan
select '✅ Tabel nama panitia siap' as hasil
where exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'lomba_panitia')
union all
select '✅ Buat ID dari nama siap'
where exists (select 1 from pg_proc where proname = 'lomba_buat_akun_nama')
union all
select '✅ Contoh: "I Made Darma Wiguna Artha" → ' || initcap(public.lomba_huruf_nama('I Made Darma Wiguna Artha')) || public.lomba_angka_acak()
where exists (select 1 from pg_proc where proname = 'lomba_huruf_nama');
