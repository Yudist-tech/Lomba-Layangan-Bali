-- =====================================================================
-- BUAT ID UNTUK SUPER ADMIN (jalankan SETELAH login-id.sql)
-- Ganti 3 nilai di bawah, lalu Run di Supabase → SQL Editor.
-- Login lama dengan email tetap bisa dipakai; ID ini jadi cara login tambahan.
-- =====================================================================
do $$
declare
  v_id    text := 'admin.ade';                  -- ← ID super admin yang Anda inginkan
  v_pw    text := 'GANTI-dengan-password-kuat'; -- ← password (minimal 8 karakter)
  v_super text := 'adeyudistira62@gmail.com';   -- ← email super admin yang SUDAH ada
  v_ev    bigint;
begin
  if v_pw = 'GANTI-dengan-password-kuat' then
    raise exception 'Ganti dulu password di baris v_pw.';
  end if;
  -- jalankan atas nama super admin yang sudah ada
  perform set_config('request.jwt.claims',
    json_build_object('sub', (select id from auth.users where lower(email) = lower(v_super)), 'role', 'authenticated')::text, true);
  select id into v_ev from public.lomba_event order by id limit 1;
  if v_ev is null then
    raise exception 'Belum ada event. Buat minimal 1 event dulu.';
  end if;
  perform public.lomba_buat_akun_id(v_ev, v_id, v_pw);
  -- jadikan super admin (bisa membuka semua event), bukan sekadar panitia satu event
  insert into public.lomba_admin (email) values (public.lomba_email_id(v_id)) on conflict do nothing;
  delete from public.lomba_event_admin where email = public.lomba_email_id(v_id);
end $$;

-- Pemeriksaan: ID baru harus muncul di daftar super admin
select replace(email, '@id.panitia.lomba', '') as super_admin,
       case when email like '%@id.panitia.lomba' then '✅ login dengan ID' else 'login dengan email' end as cara_login
  from public.lomba_admin order by created_at;
