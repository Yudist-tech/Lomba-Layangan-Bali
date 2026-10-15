-- =====================================================================
-- TEMA EVENT (versi 1.0)
-- Jalankan SETELAH multi-event.sql. Aman dijalankan ulang (idempotent).
--
-- Menambah kolom "Tema event" di Pengaturan. Tema tampil di halaman peserta,
-- tepat di bawah nama event (huruf miring dalam tanda kutip).
-- Kosong = tidak ditampilkan. Data lain tidak berubah.
-- =====================================================================

alter table public.lomba_pengaturan add column if not exists tema text not null default '';

drop function if exists public.lomba_info_publik();
create or replace function public.lomba_info_publik(p_event bigint default null)
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_ev bigint := public.lomba_ev(p_event);
  v_st public.lomba_pengaturan%rowtype;
begin
  select * into v_st from public.lomba_pengaturan where event_id = v_ev;
  if not found then
    return null;
  end if;
  return json_build_object(
    'event', json_build_object(
        'id', v_ev,
        'slug', (select slug from public.lomba_event where id = v_ev),
        'nama_event', v_st.nama_event, 'penyelenggara', v_st.penyelenggara, 'lokasi', v_st.lokasi,
        'tema', v_st.tema,
        'info', v_st.info, 'wa_admin', v_st.wa_admin,
        'bank_nama', v_st.bank_nama, 'bank_no_rek', v_st.bank_no_rek, 'bank_atas_nama', v_st.bank_atas_nama,
        'pendaftaran_buka', v_st.pendaftaran_buka and (v_st.batas_daftar is null or now() <= v_st.batas_daftar),
        'batas_daftar', v_st.batas_daftar, 'tampilkan_peserta', v_st.tampilkan_peserta,
        'logo_url', v_st.logo_url, 'bg_url', v_st.bg_url, 'flyer_url', v_st.flyer_url,
        'tanggal_mulai', v_st.tanggal_mulai, 'tanggal_selesai', v_st.tanggal_selesai),
    'hari', coalesce((
      select json_agg(json_build_object('id', h.id, 'nama', h.nama, 'tanggal', h.tanggal, 'urutan', h.urutan)
             order by h.tanggal nulls last, h.urutan, h.id)
      from public.lomba_hari h where h.event_id = v_ev), '[]'::json),
    'sesi', coalesce((
      select json_agg(json_build_object('id', s.id, 'hari_id', s.hari_id, 'nama', s.nama,
                                        'jam_mulai', s.jam_mulai, 'jam_selesai', s.jam_selesai, 'urutan', s.urutan)
             order by s.jam_mulai nulls last, s.urutan, s.id)
      from public.lomba_sesi s where s.event_id = v_ev), '[]'::json),
    'jenis', coalesce((
      select json_agg(json_build_object('kode', j.kode, 'nama', j.nama, 'harga', j.harga, 'prefix', j.prefix, 'aktif', j.aktif,
                                        'nomor_min', j.nomor_min, 'nomor_max', j.nomor_max, 'nomor_digit', j.nomor_digit)
             order by j.urutan, j.nama)
      from public.lomba_jenis j where j.event_id = v_ev), '[]'::json),
    'seri', coalesce((
      select json_agg(json_build_object(
               'id', s.id, 'jenis', s.jenis, 'nama', s.nama, 'tanggal', s.tanggal,
               'jam_mulai', s.jam_mulai, 'jam_selesai', s.jam_selesai,
               'kuota', s.kuota, 'aktif', s.aktif, 'catatan', s.catatan,
               'sesi_id', s.sesi_id, 'huruf', s.huruf, 'kotak', s.kotak, 'tutup', s.tutup,
               'terisi', (select count(*) from public.lomba_pendaftaran p
                           where p.seri_id = s.id and p.status in ('menunggu', 'terkonfirmasi')),
               'isi', (select coalesce(json_agg(json_build_object('kotak', p.kotak, 'status', p.status,
                                                                  'nomor', case when p.status = 'terkonfirmasi' then p.nomor_layangan end)
                                                order by p.kotak), '[]'::json)
                         from public.lomba_pendaftaran p
                        where p.seri_id = s.id and p.kotak is not null and p.status in ('menunggu', 'terkonfirmasi')),
               'peserta', case when v_st.tampilkan_peserta then (
                   select coalesce(json_agg(json_build_object('kotak', p.kotak, 'nomor', p.nomor_layangan,
                                                              'sekha', p.nama_sekha, 'alamat', p.alamat)
                                            order by p.kotak), '[]'::json)
                   from public.lomba_pendaftaran p
                   where p.seri_id = s.id and p.kotak is not null and p.status = 'terkonfirmasi') end)
             order by s.tanggal nulls last, s.jam_mulai nulls last, s.urutan, s.id)
      from public.lomba_seri s where s.event_id = v_ev), '[]'::json),
    'waktu_server', now());
end;
$$;

grant execute on function public.lomba_info_publik(bigint) to anon, authenticated;

-- Pemeriksaan
select '✅ Kolom tema siap' as hasil
where exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'lomba_pengaturan' and column_name = 'tema')
union all
select '✅ Halaman peserta membaca tema'
where pg_get_functiondef('public.lomba_info_publik(bigint)'::regprocedure) like '%''tema''%';
