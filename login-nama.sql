-- =====================================================================
-- ID PANITIA DARI NAMA LENGKAP (versi 1.0)
-- Jalankan SETELAH login-id.sql. Aman dijalankan ulang (idempotent).
--
-- Super admin cukup mengetik nama lengkap panitia; sistem membuat ID
-- 5 huruf dari nama + 3 angka acak, mis. "I Made Sudarma" → madsu482.
-- Nama lengkap disimpan supaya tampil di daftar admin & di dashboard.
-- =====================================================================

create table if not exists public.lomba_panitia (
  email      text primary key,
  nama       text not null,
  created_at timestamptz not null default now()
);
alter table public.lomba_panitia enable row level security;
revoke all on table public.lomba_panitia from anon, authenticated;

-- 5 huruf dari nama: 3 huruf nama depan + 2 huruf nama belakang (awalan I / Ni dilewati)
create or replace function public.lomba_huruf_nama(p_nama text)
returns text
language plpgsql
volatile
set search_path = public
as $$
declare
  w     text[];
  hasil text;
  semua text;
begin
  w := array_remove(regexp_split_to_array(lower(regexp_replace(translate(coalesce(p_nama, ''),
         'ÁÀÂÄÃÉÈÊËÍÌÎÏÓÒÔÖÕÚÙÛÜáàâäãéèêëíìîïóòôöõúùûü', 'AAAAAEEEEIIIIOOOOOUUUUaaaaaeeeeiiiiooooouuuu'),
         '[^A-Za-z ]', ' ', 'g')), '\s+'), '');
  if array_length(w, 1) > 1 and w[1] in ('i', 'ni') then
    w := w[2:];
  end if;
  semua := array_to_string(w, '');
  if coalesce(array_length(w, 1), 0) = 0 then
    hasil := '';
  elsif array_length(w, 1) = 1 then
    hasil := left(w[1], 5);
  else
    hasil := left(w[1], 3) || left(w[array_length(w, 1)], 2);
    if length(hasil) < 5 then
      hasil := left(hasil || substr(semua, length(hasil) + 1), 5);
    end if;
  end if;
  while length(hasil) < 5 loop
    hasil := hasil || chr(97 + floor(random() * 26)::int);
  end loop;
  return hasil;
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
  v_huruf := public.lomba_huruf_nama(v_nama);
  loop
    v_coba := v_coba + 1;
    v_id := v_huruf || lpad(floor(random() * 1000)::int::text, 3, '0');
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
select '✅ Contoh: "I Made Sudarma" → ' || public.lomba_huruf_nama('I Made Sudarma') || '123'
where exists (select 1 from pg_proc where proname = 'lomba_huruf_nama');
