-- =====================================================================
-- LOGIN PANITIA DENGAN ID (versi 1.0)
-- Jalankan SETELAH multi-event.sql. Aman dijalankan ulang (idempotent).
--
-- Super admin bisa membuat akun panitia berupa ID + password (tanpa email).
-- Di balik layar Supabase tetap memakai alamat email, jadi ID "sanurkaja01"
-- disimpan sebagai "sanurkaja01@id.panitia.lomba" (alamat ini tidak pernah
-- dikirimi email). Login dengan email yang sudah ada tetap berjalan seperti biasa.
-- Tidak mengubah data pendaftaran / event yang sudah ada.
-- =====================================================================

create extension if not exists pgcrypto with schema extensions;

-- ID → alamat email internal
create or replace function public.lomba_email_id(p_id text)
returns text
language sql
immutable
set search_path = public
as $$ select lower(btrim(p_id)) || '@id.panitia.lomba' $$;

-- Buat akun ID + password lalu beri akses ke event.
-- Bila ID sudah ada: cukup ditambahkan ke event ini (password lama tidak diubah).
create or replace function public.lomba_buat_akun_id(p_event bigint, p_id text, p_password text)
returns json
language plpgsql
security definer
set search_path = public, extensions, auth
as $$
declare
  v_id     text := lower(btrim(coalesce(p_id, '')));
  v_email  text;
  v_uid    uuid;
  v_ok     timestamptz;
  v_inst   uuid;
  v_baru   boolean := false;
  v_kolom  text;
begin
  perform public.lomba_wajib_super();
  if v_id !~ '^[a-z0-9][a-z0-9._-]{2,29}$' then
    raise exception 'ID_TIDAK_VALID';
  end if;
  if not exists (select 1 from public.lomba_event where id = p_event) then
    raise exception 'EVENT_TIDAK_ADA';
  end if;
  v_email := public.lomba_email_id(v_id);

  select id, email_confirmed_at into v_uid, v_ok from auth.users where lower(email) = v_email limit 1;

  if v_uid is null or v_ok is null then
    if length(coalesce(p_password, '')) < 8 then
      raise exception 'PASSWORD_PENDEK';
    end if;
  end if;

  if v_uid is null then
    v_uid  := gen_random_uuid();
    v_baru := true;
    select instance_id into v_inst from auth.users where instance_id is not null limit 1;
    insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                            raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                            confirmation_token, recovery_token, email_change_token_new, email_change)
    values (coalesce(v_inst, '00000000-0000-0000-0000-000000000000'), v_uid, 'authenticated', 'authenticated', v_email,
            crypt(p_password, gen_salt('bf')), now(),
            jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email')),
            jsonb_build_object('panitia_id', v_id), now(), now(), '', '', '', '');
    -- kolom token lain (bergantung versi Supabase) tidak boleh NULL agar login berjalan
    for v_kolom in
      select column_name from information_schema.columns
       where table_schema = 'auth' and table_name = 'users'
         and column_name in ('email_change_token_current', 'phone_change', 'phone_change_token', 'reauthentication_token')
    loop
      execute format('update auth.users set %I = coalesce(%I, '''') where id = $1', v_kolom, v_kolom) using v_uid;
    end loop;
    -- identitas login email (versi baru memakai kolom provider_id)
    if exists (select 1 from information_schema.columns where table_schema = 'auth' and table_name = 'identities' and column_name = 'provider_id') then
      execute 'insert into auth.identities (id, provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
               values (gen_random_uuid(), $1::text, $1, $2, ''email'', now(), now(), now())'
        using v_uid, jsonb_build_object('sub', v_uid::text, 'email', v_email, 'email_verified', true, 'phone_verified', false);
    elsif exists (select 1 from information_schema.tables where table_schema = 'auth' and table_name = 'identities') then
      execute 'insert into auth.identities (id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
               values ($1::text, $1, $2, ''email'', now(), now(), now())'
        using v_uid, jsonb_build_object('sub', v_uid::text, 'email', v_email);
    end if;
  elsif v_ok is null then
    -- akun belum pernah aktif (mis. terdaftar tanpa konfirmasi): ambil alih dengan password baru
    update auth.users
       set encrypted_password = crypt(p_password, gen_salt('bf')),
           email_confirmed_at = now(), updated_at = now()
     where id = v_uid;
    v_baru := true;
  end if;

  insert into public.lomba_event_admin (event_id, email) values (p_event, v_email)
  on conflict do nothing;

  return json_build_object('id', v_id, 'email', v_email, 'baru', v_baru);
end;
$$;

-- Reset password akun ID (hanya untuk akun ID, bukan akun email biasa)
create or replace function public.lomba_reset_password_id(p_id text, p_password text)
returns void
language plpgsql
security definer
set search_path = public, extensions, auth
as $$
declare
  v_email text := public.lomba_email_id(regexp_replace(coalesce(p_id, ''), '@id\.panitia\.lomba$', ''));
begin
  perform public.lomba_wajib_super();
  if length(coalesce(p_password, '')) < 8 then
    raise exception 'PASSWORD_PENDEK';
  end if;
  update auth.users
     set encrypted_password = crypt(p_password, gen_salt('bf')),
         email_confirmed_at = coalesce(email_confirmed_at, now()), updated_at = now()
   where lower(email) = v_email;
  if not found then
    raise exception 'ID_TIDAK_ADA';
  end if;
end;
$$;

revoke all on function public.lomba_buat_akun_id(bigint, text, text) from public, anon;
revoke all on function public.lomba_reset_password_id(text, text) from public, anon;
grant execute on function public.lomba_buat_akun_id(bigint, text, text) to authenticated;
grant execute on function public.lomba_reset_password_id(text, text) to authenticated;
grant execute on function public.lomba_email_id(text) to authenticated, anon;

-- Pemeriksaan
select '✅ Fungsi buat akun ID siap' as hasil
where exists (select 1 from pg_proc where proname = 'lomba_buat_akun_id')
union all
select '✅ Fungsi reset password ID siap'
where exists (select 1 from pg_proc where proname = 'lomba_reset_password_id')
union all
select '✅ pgcrypto tersedia'
where exists (select 1 from pg_extension where extname = 'pgcrypto');
