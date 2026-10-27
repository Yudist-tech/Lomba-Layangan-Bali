-- =====================================================================
--  ID PANITIA: 3 ANGKA AKHIR BERPOLA (mudah dihafal)
--  Jalankan SEKALI di Supabase → SQL Editor. Aman dijalankan ulang.
--  Hanya mengganti fungsi pembuat angka; akun yang sudah ada TIDAK berubah.
--  Contoh angka baru: 751, 852, 159, 246, 357, 147, 580 …
-- =====================================================================
create or replace function public.lomba_angka_acak()
returns text
language plpgsql
volatile
set search_path = public
as $$
declare
  -- pola mudah dihafal di papan angka HP: garis / huruf V lewat angka 5 (751, 852, 159),
  -- lompat dua (246, 135), kolom (147, 369, 580)
  pola text[] := array['024', '085', '135', '147', '152', '153', '154', '156', '157', '158', '159', '246', '251', '253', '254', '256', '257', '258', '259', '351', '352', '354', '356', '357', '358', '359', '369', '420', '451', '452', '453', '457', '458', '459', '468', '531', '579', '580', '642', '651', '652', '653', '657', '658', '659', '741', '751', '752', '753', '754', '756', '758', '759', '851', '852', '853', '854', '856', '857', '859', '864', '951', '952', '953', '954', '956', '957', '958', '963', '975'];
begin
  return pola[1 + floor(random() * array_length(pola, 1))::int];
end;
$$;
