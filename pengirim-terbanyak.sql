-- =====================================================================
-- PENGIRIM TERBANYAK (versi 1.0)
-- Jalankan SETELAH multi-event.sql. Aman dijalankan ulang (idempotent).
-- Hanya MENAMBAH tabel & fungsi baru — data lama tidak diubah / dihapus.
--
-- Peringkat dihitung di aplikasi dari nomor WA pendaftaran TERKONFIRMASI.
-- Tabel ini hanya menyimpan: jumlah juara yang diumumkan, urutan untuk
-- jumlah yang sama (tombol Naikkan), daftar juara, dan waktu pengumuman.
-- =====================================================================

create table if not exists public.lomba_pengirim (
  event_id      bigint primary key references public.lomba_event(id) on delete cascade,
  jumlah_juara  int not null default 3 check (jumlah_juara between 1 and 20),
  prioritas     jsonb not null default '{}'::jsonb,   -- { "62812...": 1, ... } urutan bila jumlahnya sama
  nama          jsonb not null default '{}'::jsonb,   -- { "62812...": "Nama tampil" } nama diubah panitia (nomor WA tetap)
  juara         jsonb,                                 -- [{ "urutan":1, "wa":"62812...", "wa_samar":"0812-xxxx-4471", "nama":"...", "jumlah":14 }]
  diumumkan_at  timestamptz,
  oleh          text,
  updated_at    timestamptz not null default now()
);

create or replace function public.lomba_trg_pengirim()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.oleh := public.lomba_email_saya();
  new.updated_at := now();
  return new;
end;
$$;
drop trigger if exists lomba_pengirim_biu on public.lomba_pengirim;
create trigger lomba_pengirim_biu before insert or update on public.lomba_pengirim
  for each row execute function public.lomba_trg_pengirim();
revoke all on function public.lomba_trg_pengirim() from public, anon, authenticated;

-- keamanan: hanya panitia event itu
alter table public.lomba_pengirim enable row level security;
drop policy if exists lomba_admin_kelola on public.lomba_pengirim;
create policy lomba_admin_kelola on public.lomba_pengirim for all to authenticated
  using ((select public.lomba_boleh_event(event_id)))
  with check ((select public.lomba_boleh_event(event_id)));
revoke all on table public.lomba_pengirim from anon;
grant select, insert, update, delete on table public.lomba_pengirim to authenticated;
grant select, insert, update, delete on table public.lomba_pengirim to service_role;

-- halaman peserta: juara pengirim terbanyak (nomor WA disamarkan, mis. 0812-xxxx-4471), hanya setelah diumumkan
create or replace function public.lomba_pengirim_publik(p_event bigint default null)
returns json
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((
    select json_build_object('diumumkan_at', p.diumumkan_at,
             'list', coalesce((select json_agg(json_build_object('urutan', (x->>'urutan')::int, 'nama', x->>'nama', 'jumlah', (x->>'jumlah')::int, 'wa', x->>'wa_samar'))
                                 from jsonb_array_elements(coalesce(p.juara, '[]'::jsonb)) x), '[]'::json))
      from public.lomba_pengirim p
     where p.event_id = public.lomba_ev(p_event) and p.diumumkan_at is not null), json_build_object('diumumkan_at', null, 'list', '[]'::json));
$$;
revoke all on function public.lomba_pengirim_publik(bigint) from public;
grant execute on function public.lomba_pengirim_publik(bigint) to anon, authenticated;

alter table public.lomba_pengirim add column if not exists nama jsonb not null default '{}'::jsonb;

-- Pemeriksaan
select '✅ Tabel pengirim terbanyak siap' as hasil
where to_regclass('public.lomba_pengirim') is not null
union all
select '✅ Pengirim terbanyak tampil di halaman juara peserta'
where exists (select 1 from pg_proc where proname = 'lomba_pengirim_publik');
