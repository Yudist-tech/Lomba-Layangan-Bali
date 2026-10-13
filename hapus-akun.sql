-- =====================================================================
-- HAPUS AKUN ID PANITIA (versi 1.0)
-- Jalankan SETELAH login-id.sql & login-nama.sql. Aman dijalankan ulang.
--
-- Super admin bisa menghapus akun ID panitia sampai bersih: login, password,
-- nama lengkap, dan semua akses event. ID itu tidak bisa dipakai login lagi.
-- Data pendaftaran & konfirmasi yang pernah dikerjakan TIDAK ikut terhapus.
-- Akun super admin dan akun email tidak bisa dihapus lewat fungsi ini.
-- =====================================================================

create or replace function public.lomba_hapus_akun_id(p_id text)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_email text := public.lomba_email_id(regexp_replace(lower(btrim(coalesce(p_id, ''))), '@id\.panitia\.lomba$', ''));
  v_uid   uuid;
begin
  perform public.lomba_wajib_super();
  if v_email = public.lomba_email_saya() then
    raise exception 'AKUN_SENDIRI';
  end if;
  if exists (select 1 from public.lomba_admin where lower(email) = v_email) then
    raise exception 'EMAIL_SUPER';
  end if;
  select id into v_uid from auth.users where lower(email) = v_email limit 1;

  delete from public.lomba_event_admin where email = v_email;
  if to_regclass('public.lomba_panitia') is not null then
    execute 'delete from public.lomba_panitia where email = $1' using v_email;
  end if;

  if v_uid is null then
    return;   -- akun login sudah tidak ada; sisa akses/nama sudah dibersihkan
  end if;
  -- file yang pernah diunggah akun ini (mis. flyer) tetap ada, hanya pemiliknya dikosongkan
  begin
    execute 'update storage.objects set owner = null where owner = $1' using v_uid;
  exception when others then null;
  end;
  delete from auth.users where id = v_uid;   -- sesi, identitas & token ikut terhapus
end;
$$;

revoke all on function public.lomba_hapus_akun_id(text) from public, anon;
grant execute on function public.lomba_hapus_akun_id(text) to authenticated;

-- Pemeriksaan
select '✅ Fungsi hapus akun ID siap' as hasil
where exists (select 1 from pg_proc where proname = 'lomba_hapus_akun_id');
