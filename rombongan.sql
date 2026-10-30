-- =====================================================================
-- DAFTAR BEBERAPA LAYANGAN SEKALIGUS (ROMBONGAN) — versi 1.0
-- Jalankan SETELAH cadangan-sebelum-rombongan.sql (backup dulu!).
-- SQL Editor → paste seluruh isi → Run. Aman dijalankan ulang.
--
-- Yang ditambahkan / diubah:
--   • Kolom baru di lomba_pendaftaran:
--       rombongan        kode bersama, mis. RB-7K2QAB (kosong = daftar 1 layangan)
--       rb_urut          urutan layangan di formulir (0, 1, 2 …)
--       rb_tolak         pilihan panitia ✕ (batal) sebelum disimpan
--       rb_hubungi_oleh  panitia yang sedang menghubungi peserta
--       rb_hubungi_at    sejak kapan
--   • Bukti transfer boleh dipakai bersama oleh layangan dalam 1 rombongan
--     (di luar rombongan tetap: 1 bukti = 1 pendaftaran).
--   • Fungsi baru lomba_daftar_rombongan: 2–10 layangan, 1 nomor WA, 1 bukti.
--     Gagal satu layangan → tidak ada yang tersimpan.
--   • lomba_cek_status : ikut mengirim kode rombongan (tampil 1 kartu per rombongan).
--   • lomba_tiket      : link PDF rombongan (RB-…) berisi layangan yang terkonfirmasi.
--   • lomba_event_dari_kode : mengenali kode rombongan.
-- Data lama TIDAK diubah atau dihapus.
-- =====================================================================

-- 1) KOLOM -------------------------------------------------------------
alter table public.lomba_pendaftaran add column if not exists rombongan text;
alter table public.lomba_pendaftaran add column if not exists rb_urut smallint;
alter table public.lomba_pendaftaran add column if not exists rb_tolak boolean not null default false;
alter table public.lomba_pendaftaran add column if not exists rb_hubungi_oleh text;
alter table public.lomba_pendaftaran add column if not exists rb_hubungi_at timestamptz;
create index if not exists lomba_pendaftaran_rombongan_idx on public.lomba_pendaftaran (rombongan) where rombongan is not null;

-- 1 bukti = 1 pendaftaran, KECUALI layangan dalam rombongan yang sama
drop index if exists public.lomba_pendaftaran_bukti_uidx;
create unique index if not exists lomba_pendaftaran_bukti_uidx on public.lomba_pendaftaran (bukti_path)
  where bukti_path is not null and rombongan is null;

-- 2) KODE ROMBONGAN ----------------------------------------------------
create or replace function public.lomba_kode_rombongan_baru()
returns text
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  abc constant text := '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  v text;
begin
  loop
    v := 'RB-';
    for i in 1..6 loop
      v := v || substr(abc, 1 + floor(random() * 32)::int, 1);
    end loop;
    exit when not exists (select 1 from public.lomba_pendaftaran where rombongan = v);
  end loop;
  return v;
end;
$$;

-- ringkasan 1 rombongan untuk peserta (setelah mendaftar)
create or replace function public.lomba_ringkas_rombongan(p_kode text)
returns json
language sql
stable
security definer
set search_path = public
as $$
  select json_build_object(
    'rombongan', p_kode,
    'no_wa', min(p.no_wa),
    'created_at', min(p.created_at),
    'total', sum(p.harga),
    'items', json_agg(json_build_object('kode', p.kode, 'jenis', p.jenis, 'seri_id', p.seri_id, 'nomor_layangan', p.nomor_layangan,
                                        'nama_sekha', p.nama_sekha, 'alamat', p.alamat, 'harga', p.harga, 'kotak', p.kotak)
                      order by p.rb_urut, p.created_at))
  from public.lomba_pendaftaran p
  where p.rombongan = p_kode;
$$;

-- 3) DAFTAR ROMBONGAN --------------------------------------------------
-- p_items: [{ jenis, seri_id, nomor_layangan, nama_sekha, alamat, harga }, …]  (2–10 layangan)
-- Error membawa urutan layangan yang bermasalah, mis. "NOMOR_DIPAKAI:2" (0 = layangan pertama).
create or replace function public.lomba_daftar_rombongan(
  p_no_wa          text,
  p_nama_rekening  text,
  p_bukti_path     text,
  p_bukti_hash     text default null,
  p_client_ref     uuid default null,
  p_items          jsonb default '[]'::jsonb,
  p_event          bigint default null
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ev     bigint := public.lomba_ev(p_event);
  v_set    public.lomba_pengaturan%rowtype;
  v_jenis  public.lomba_jenis%rowtype;
  v_seri   public.lomba_seri%rowtype;
  v_wa     text;
  v_ip     text;
  v_iphash text;
  v_ada    boolean;
  v_n      int;
  v_kode   text;
  v_lama   text;
  v_it     jsonb;
  v_i      int;
  v_nomor  text;
  v_jk     text;
  v_seri_id bigint;
  v_err    text;
  v_con    text;
begin
  -- kirim ulang (mis. koneksi putus) → kembalikan rombongan yang sama, tidak dobel
  if p_client_ref is not null then
    select rombongan into v_lama from public.lomba_pendaftaran where client_ref = p_client_ref and rombongan is not null;
    if v_lama is not null then
      return public.lomba_ringkas_rombongan(v_lama);
    end if;
  end if;

  select * into v_set from public.lomba_pengaturan where event_id = v_ev;
  if not found or not v_set.pendaftaran_buka
     or (v_set.batas_daftar is not null and now() > v_set.batas_daftar) then
    raise exception 'PENDAFTARAN_DITUTUP';
  end if;

  if jsonb_typeof(p_items) is distinct from 'array' then
    raise exception 'JUMLAH_ROMBONGAN';
  end if;
  v_n := jsonb_array_length(p_items);
  if v_n < 2 or v_n > 10 then
    raise exception 'JUMLAH_ROMBONGAN';
  end if;

  v_wa := public.lomba_normalisasi_wa(p_no_wa);
  if v_wa is null then
    raise exception 'WA_TIDAK_VALID';
  end if;
  if char_length(btrim(coalesce(p_nama_rekening, ''))) not between 2 and 120 then
    raise exception 'DATA_TIDAK_LENGKAP';
  end if;

  -- bukti: file sudah diunggah & belum dipakai pendaftaran lain
  if p_bukti_path is null
     or p_bukti_path !~ '^bukti/[0-9a-f-]{36}\.(jpg|jpeg|png|webp|pdf)$' then
    raise exception 'BUKTI_TIDAK_VALID';
  end if;
  begin
    select exists (select 1 from storage.objects
                   where bucket_id = 'lomba-bukti' and name = p_bukti_path) into v_ada;
  exception when others then
    v_ada := true;
  end;
  if not v_ada or exists (select 1 from public.lomba_pendaftaran where bukti_path = p_bukti_path) then
    raise exception 'BUKTI_TIDAK_VALID';
  end if;

  -- rem anti-spam (dihitung bersama layangan di rombongan ini)
  if (select count(*) from public.lomba_pendaftaran
      where no_wa = v_wa and created_at > now() - interval '1 hour') + v_n > 25 then
    raise exception 'TERLALU_BANYAK';
  end if;
  begin
    v_ip := nullif(btrim(split_part(coalesce(
              current_setting('request.headers', true)::json ->> 'cf-connecting-ip',
              current_setting('request.headers', true)::json ->> 'x-forwarded-for',
              current_setting('request.headers', true)::json ->> 'x-real-ip', ''), ',', 1)), '');
  exception when others then
    v_ip := null;
  end;
  if v_ip is not null then
    v_iphash := left(encode(sha256(convert_to('lomba:' || v_ip, 'UTF8')), 'hex'), 16);
    if (select count(*) from public.lomba_pendaftaran
        where ip_hash = v_iphash and created_at > now() - interval '10 minutes') + v_n > 40 then
      raise exception 'TERLALU_BANYAK';
    end if;
  end if;

  v_kode := public.lomba_kode_rombongan_baru();

  for v_it, v_i in select e, (o - 1)::int from jsonb_array_elements(p_items) with ordinality as t(e, o) loop
    v_jk := v_it ->> 'jenis';
    begin
      v_seri_id := nullif(v_it ->> 'seri_id', '')::bigint;
    exception when others then
      raise exception 'SERI_TIDAK_VALID:%', v_i;
    end;

    select * into v_jenis from public.lomba_jenis where event_id = v_ev and kode = v_jk;
    if not found or not v_jenis.aktif then
      raise exception 'JENIS_TIDAK_VALID:%', v_i;
    end if;
    if (v_it ->> 'harga') is not null and (v_it ->> 'harga') ~ '^[0-9]+$' and (v_it ->> 'harga')::int <> v_jenis.harga then
      raise exception 'HARGA_BERUBAH:%', v_i;
    end if;

    select * into v_seri from public.lomba_seri where id = v_seri_id and event_id = v_ev;
    if not found or v_seri.jenis <> v_jk or not v_seri.aktif or v_seri.sesi_id is null then
      raise exception 'SERI_TIDAK_VALID:%', v_i;
    end if;

    v_nomor := btrim(coalesce(v_it ->> 'nomor_layangan', ''));
    if v_nomor !~ '^[0-9]{1,6}$' then
      raise exception 'NOMOR_TIDAK_VALID:%', v_i;
    end if;
    v_nomor := public.lomba_rapikan_nomor(v_nomor, v_jenis.nomor_digit);
    if v_jenis.nomor_min is not null and v_nomor::bigint not between v_jenis.nomor_min and v_jenis.nomor_max then
      raise exception 'NOMOR_DILUAR_RENTANG:%', v_i;
    end if;
    -- juga menangkap nomor kembar di dalam rombongan ini (baris sebelumnya sudah tersimpan)
    if exists (select 1 from public.lomba_pendaftaran
                where event_id = v_ev and jenis = v_jk and nomor_layangan = v_nomor
                  and status in ('menunggu', 'terkonfirmasi')) then
      raise exception 'NOMOR_DIPAKAI:%', v_i;
    end if;

    if char_length(btrim(coalesce(v_it ->> 'nama_sekha', ''))) not between 2 and 120
       or char_length(btrim(coalesce(v_it ->> 'alamat', ''))) not between 3 and 300 then
      raise exception 'DATA_TIDAK_LENGKAP:%', v_i;
    end if;

    begin
      insert into public.lomba_pendaftaran
        (event_id, client_ref, jenis, seri_id, nama_sekha, alamat, no_wa, nama_rekening,
         bukti_path, bukti_hash, harga, status, ip_hash, nomor_layangan, rombongan, rb_urut)
      values
        (v_ev, case when v_i = 0 then p_client_ref end, v_jk, v_seri_id, v_it ->> 'nama_sekha', v_it ->> 'alamat', v_wa, p_nama_rekening,
         p_bukti_path, left(p_bukti_hash, 128), v_jenis.harga, 'menunggu', v_iphash, v_nomor, v_kode, v_i);
    exception
      when unique_violation then
        get stacked diagnostics v_con = constraint_name;
        if coalesce(v_con, '') like '%nomor%' then raise exception 'NOMOR_DIPAKAI:%', v_i; end if;
        if coalesce(v_con, '') like '%kotak%' then raise exception 'KUOTA_PENUH:%', v_i; end if;
        if coalesce(v_con, '') like '%client_ref%' then raise exception 'KIRIM_ULANG'; end if;
        raise exception 'BUKTI_TIDAK_VALID';
      when raise_exception then
        v_err := sqlerrm;   -- dari trigger: KUOTA_PENUH, NOMOR_DIPAKAI, SERI_TIDAK_VALID, …
        if v_err ~ '^[A-Z_]+$' then raise exception '%:%', v_err, v_i; end if;
        raise;
    end;
  end loop;

  return public.lomba_ringkas_rombongan(v_kode);
exception
  when others then
    -- kiriman ganda bersamaan dengan client_ref yang sama: kembalikan yang sudah tersimpan
    if sqlerrm = 'KIRIM_ULANG' and p_client_ref is not null then
      select rombongan into v_lama from public.lomba_pendaftaran where client_ref = p_client_ref and rombongan is not null;
      if v_lama is not null then
        return public.lomba_ringkas_rombongan(v_lama);
      end if;
    end if;
    raise;
end;
$$;

-- 4) CEK STATUS: ikut mengirim kode & urutan rombongan --------------------
create or replace function public.lomba_cek_status(p_no_wa text, p_event bigint default null)
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_wa text := public.lomba_normalisasi_wa(p_no_wa);
  v_ev bigint := public.lomba_ev(p_event);
begin
  if v_wa is null then
    raise exception 'WA_TIDAK_VALID';
  end if;
  return coalesce((
    select json_agg(x order by x.created_at desc, x.rb_urut)
    from (
      select p.kode, p.jenis, j.nama as jenis_nama, p.nama_sekha, p.status,
             p.nomor_layangan, p.kotak, p.alasan_tolak, p.harga, p.created_at,
             p.rombongan, p.rb_urut,
             s.nama as seri_nama, s.tanggal, s.jam_mulai, s.jam_selesai
      from public.lomba_pendaftaran p
      join public.lomba_jenis j on j.event_id = p.event_id and j.kode = p.jenis
      join public.lomba_seri s on s.id = p.seri_id
      where p.no_wa = v_wa and p.event_id = v_ev
      order by p.created_at desc
      limit 50
    ) x
  ), '[]'::json);
end;
$$;

-- 5) TIKET / PDF: kode LL-… (1 layangan) atau RB-… (rombongan, hanya yang terkonfirmasi)
create or replace function public.lomba_tiket(p_kode text)
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_kode text := upper(btrim(coalesce(p_kode, '')));
  v_ev   bigint;
begin
  if v_kode ~ '^RB-[0-9A-Z]{6}$' then
    select p.event_id into v_ev from public.lomba_pendaftaran p
     where p.rombongan = v_kode and p.status = 'terkonfirmasi' limit 1;
    if v_ev is null then
      return null;
    end if;
    return (
      select json_build_object(
        'event', (select json_build_object('nama_event', st.nama_event, 'penyelenggara', st.penyelenggara,
                                           'lokasi', st.lokasi, 'logo_url', st.logo_url, 'bg_url', st.bg_url)
                    from public.lomba_pengaturan st where st.event_id = v_ev),
        'event_slug', (select e.slug from public.lomba_event e where e.id = v_ev),
        'rombongan', v_kode, 'no_wa', min(p.no_wa), 'nama_rekening', min(p.nama_rekening), 'total', sum(p.harga),
        'items', json_agg(json_build_object(
          'kode', p.kode, 'nomor_layangan', p.nomor_layangan, 'jenis', j.nama, 'jenis_kode', p.jenis,
          'nama_sekha', p.nama_sekha, 'alamat', p.alamat, 'no_wa', p.no_wa, 'harga', p.harga,
          'kotak', p.kotak, 'seri_nama', s.nama, 'huruf', s.huruf, 'sesi_nama', ss.nama, 'hari', h.nama,
          'tanggal', s.tanggal, 'jam_mulai', s.jam_mulai, 'jam_selesai', s.jam_selesai) order by p.rb_urut, p.created_at))
      from public.lomba_pendaftaran p
      join public.lomba_jenis j on j.event_id = p.event_id and j.kode = p.jenis
      join public.lomba_seri s on s.id = p.seri_id
      left join public.lomba_sesi ss on ss.id = s.sesi_id
      left join public.lomba_hari h on h.id = ss.hari_id
      where p.rombongan = v_kode and p.status = 'terkonfirmasi'
    );
  end if;
  if v_kode !~ '^LL-[0-9A-Z]{6}$' then
    return null;
  end if;
  return (
    select json_build_object(
      'event', (select json_build_object('nama_event', st.nama_event, 'penyelenggara', st.penyelenggara,
                                         'lokasi', st.lokasi, 'logo_url', st.logo_url, 'bg_url', st.bg_url)
                  from public.lomba_pengaturan st where st.event_id = p.event_id),
      'event_slug', (select e.slug from public.lomba_event e where e.id = p.event_id),
      'kode', p.kode, 'nomor_layangan', p.nomor_layangan, 'jenis', j.nama,
      'nama_sekha', p.nama_sekha, 'alamat', p.alamat,
      'no_wa', p.no_wa,
      'kotak', p.kotak, 'seri_nama', s.nama, 'huruf', s.huruf, 'sesi_nama', ss.nama, 'hari', h.nama,
      'tanggal', s.tanggal, 'jam_mulai', s.jam_mulai, 'jam_selesai', s.jam_selesai)
    from public.lomba_pendaftaran p
    join public.lomba_jenis j on j.event_id = p.event_id and j.kode = p.jenis
    join public.lomba_seri s on s.id = p.seri_id
    left join public.lomba_sesi ss on ss.id = s.sesi_id
    left join public.lomba_hari h on h.id = ss.hari_id
    where p.kode = v_kode and p.status = 'terkonfirmasi'
  );
end;
$$;

-- kode event pemilik sebuah kode pendaftaran / kode rombongan (link konfirmasi)
create or replace function public.lomba_event_dari_kode(p_kode text)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select e.slug from public.lomba_pendaftaran p join public.lomba_event e on e.id = p.event_id
   where p.kode = upper(btrim(coalesce(p_kode, ''))) or p.rombongan = upper(btrim(coalesce(p_kode, '')))
   limit 1;
$$;

-- 6) HAK AKSES ---------------------------------------------------------
revoke all on function public.lomba_kode_rombongan_baru() from public, anon, authenticated;
revoke all on function public.lomba_ringkas_rombongan(text) from public, anon, authenticated;
revoke all on function public.lomba_daftar_rombongan(text, text, text, text, uuid, jsonb, bigint) from public;
grant execute on function public.lomba_daftar_rombongan(text, text, text, text, uuid, jsonb, bigint) to anon, authenticated;
grant execute on function public.lomba_cek_status(text, bigint) to anon, authenticated;
grant execute on function public.lomba_tiket(text) to anon, authenticated;
grant execute on function public.lomba_event_dari_kode(text) to anon, authenticated;

notify pgrst, 'reload schema';

-- 7) CEK HASIL ---------------------------------------------------------
select 'kolom rombongan' as bagian,
       case when exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'lomba_pendaftaran' and column_name = 'rombongan') then '✅' else '❌' end as hasil
union all
select 'fungsi lomba_daftar_rombongan',
       case when exists (select 1 from pg_proc where proname = 'lomba_daftar_rombongan') then '✅' else '❌' end
union all
select 'bukti boleh dipakai bersama dalam rombongan',
       case when exists (select 1 from pg_indexes where indexname = 'lomba_pendaftaran_bukti_uidx' and indexdef like '%rombongan IS NULL%') then '✅' else '❌' end;
