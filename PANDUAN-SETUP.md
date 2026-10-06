# Panduan Setup — Sistem Pendaftaran Lomba Layangan

Isi folder:

| File | Fungsi |
|---|---|
| `index.html` | Aplikasi lengkap dalam 1 file: halaman peserta + dashboard panitia |
| `setup.sql` | Dijalankan **sekali** di Supabase (tabel, keamanan, penyimpanan bukti transfer) |
| `PANDUAN-SETUP.md` | File ini |

Alamat halaman (setelah online):

- Peserta: `https://NAMA-PROJECT.pages.dev` → tab **Daftar**, **Jadwal**, **Cek Status**
- Dashboard panitia: `https://NAMA-PROJECT.pages.dev/#admin`

---

## 0. Coba dulu (mode demo, 1 menit)

Double-click `index.html`. Selama `SUPABASE_URL` dan `SUPABASE_KEY` masih kosong, aplikasi berjalan dalam **MODE DEMO**: data hanya tersimpan di browser itu dan sudah berisi data contoh.

- Halaman peserta: buka `index.html`
- Dashboard: tambahkan `#admin` di belakang alamatnya, login dengan email & password apa saja
- Reset demo: Dashboard → Pengaturan → Zona berbahaya

---

## 1. Siapkan Supabase (±10 menit)

1. Masuk ke supabase.com → **New project** (boleh juga pakai project yang sudah ada, misalnya project PMS — semua tabel berawalan `lomba_` jadi tidak bentrok).
2. Buka **SQL Editor → New query** → paste **seluruh** isi `setup.sql` → **Run**.
   Kalau muncul peringatan *destructive operation*, pilih tetap jalankan — skrip ini aman dijalankan ulang dan tidak menghapus data pendaftaran.
3. Lihat tabel hasil di bawah editor: semua baris harus ✅.
   Kalau baris **Bucket** atau **Policy Storage** ❌, ikuti **Lampiran A**.
4. **Authentication → Users → Add user → Create new user**
   - Email: `adeyudistira62@gmail.com` (harus sama dengan yang ada di BAGIAN 10 `setup.sql`)
   - Password: Yudistira_01
   - Centang **Auto Confirm User** (wajib — sistem hanya mengakui admin yang emailnya terkonfirmasi)
5. **Authentication → Sign In / Providers** → matikan **Allow new users to sign up**, supaya orang lain tidak bisa membuat akun.
6. Ambil 2 nilai ini dari tombol **Connect** di atas dashboard (atau **Project Settings → API Keys**):
   - **Project URL** → contoh `https://abcdefghijk.supabase.co`
   - **Publishable key** → diawali `sb_publishable_...` (kalau project lama: *anon public key*)
   - ⚠️ Jangan pernah memakai *secret key* / *service_role key* di file HTML.

## 2. Hubungkan index.html

Buka `index.html` dengan editor teks (VS Code / TextEdit mode teks), cari bagian **KONFIGURASI** di awal `<script>`, lalu isi:

```js
SUPABASE_URL: 'https://abcdefghijk.supabase.co',
SUPABASE_KEY: 'sb_publishable_xxxxxxxxxxxxxxxx',
```

Simpan, buka lagi di browser. Banner kuning **MODE DEMO** hilang = sudah tersambung ke database online.

## 3. Online-kan (Cloudflare Pages, gratis)

1. dash.cloudflare.com → **Workers & Pages → Create application → Get started → Drag and drop your files**.
2. Beri nama project (mis. `lomba-layangan`) → upload folder yang **hanya berisi `index.html`** → **Deploy site**.
3. Link peserta: `https://lomba-layangan.pages.dev` · Dashboard: `https://lomba-layangan.pages.dev/#admin`
4. Update versi berikutnya: buka project → **Create new deployment** → upload lagi.

`setup.sql` dan panduan ini **tidak perlu** di-upload.

## 4. Sebelum pendaftaran dibuka

1. Dashboard → **Pengaturan**: nama event, penyelenggara, lokasi, nomor WA panitia, info & ketentuan, **rekening pembayaran**, harga & awalan nomor tiap jenis, template pesan WA.
2. **Seri & Jadwal**: isi tanggal & jam tiap seri, tambah seri sesuai kebutuhan (kuota default 60). Tombol **Duplikat** mempercepat membuat seri berikutnya.
3. Uji coba: daftar 1–2 kali dari HP → verifikasi di dashboard → kirim WA ke nomor sendiri.
4. Bersihkan data uji: Pengaturan → Zona berbahaya → **Hapus semua pendaftaran** (nomor layangan kembali mulai 001).
5. Bagikan link: Pengaturan → Link & berbagi → **Bagikan via WA**.

---

## Alur kerja harian

1. Peserta mengisi 3 langkah: **Data → Konfirmasi (tampil biaya & rekening) → Upload bukti transfer**. Status awal *Menunggu*, dan slot seri langsung terpakai.
2. Dashboard → **Verifikasi**: cocokkan bukti transfer dengan tagihan → **Konfirmasi pembayaran** → nomor layangan keluar otomatis (BB-001, JG-001, CT-001, dst).
3. Klik **Kirim WA konfirmasi** → WhatsApp terbuka dengan pesan sudah terisi → tekan Kirim → kembali ke dashboard → **Berikutnya**.
4. Bukti bermasalah → **Tolak** + alasan → **Kirim WA penolakan**. Slot seri dilepas otomatis.
5. Peserta bayar tunai di tempat → Pendaftaran → **Tambah manual**.
6. Spam/pendaftaran palsu → filter *Menunggu* → **Tolak massal…**
7. Hari-H → Seri & Jadwal → **Cetak** (daftar peserta per seri + kolom hadir). Rekap lengkap → Pendaftaran → **Excel**.

## Aturan yang dijaga otomatis oleh database

- **Kuota per seri** dihitung dari pendaftaran *menunggu + terkonfirmasi*; aman walau banyak orang mendaftar bersamaan.
- **Nomor layangan** per jenis, keluar saat dikonfirmasi, tidak pernah dobel. Batal konfirmasi → nomornya tetap milik pendaftaran itu.
- **Harga** tersimpan saat mendaftar. Mengubah harga hanya berlaku untuk pendaftaran baru; peserta yang sedang membayar saat harga berubah diminta cek ulang.
- **Bukti transfer** wajib benar-benar terunggah; satu bukti yang dipakai >1 pendaftaran ditandai *Bukti dobel*.
- **Rem spam**: maks 15 pendaftaran per nomor WA per jam dan 30 per jaringan internet per 10 menit.
- **Data peserta & bukti transfer** hanya bisa dibuka admin. Cek Status hanya menampilkan nama sekha, jenis, seri, status, dan nomor layangan.
- Dua admin membuka data yang sama → yang terlambat diberi tahu dan datanya dimuat ulang, tidak saling menimpa.

---

## Lampiran A — kalau Bucket / Policy Storage ❌

**Storage → New bucket**

- Name: `lomba-bukti` · Public: **off**
- File size limit: **3 MB**
- Allowed MIME types: `image/jpeg, image/png, image/webp, application/pdf`

**Storage → Policies → lomba-bukti → New policy → For full customization** (buat 3):

| Nama policy | Operasi | Role | Definisi |
|---|---|---|---|
| `lomba_bukti_upload` | INSERT | anon, authenticated | `bucket_id = 'lomba-bukti' and (storage.foldername(name))[1] = 'bukti'` |
| `lomba_bukti_admin_baca` | SELECT | authenticated | `bucket_id = 'lomba-bukti' and (select public.lomba_is_admin())` |
| `lomba_bukti_admin_hapus` | DELETE | authenticated | `bucket_id = 'lomba-bukti' and (select public.lomba_is_admin())` |

Nama harus berawalan `lomba_bukti_` agar terdeteksi di Dashboard → Pengaturan → **Status sistem → Periksa**.

## Lampiran B — Tanya jawab

- **Tambah admin lain**: SQL Editor → `insert into lomba_admin (email) values ('email@contoh.com');` lalu buat user-nya di Authentication (Auto Confirm User).
- **Lupa password admin**: Authentication → Users → pilih user → kirim reset password, atau hapus & buat ulang user dengan email yang sama.
- **Menutup pendaftaran**: Pengaturan → Status pendaftaran (manual, atau otomatis pada tanggal & jam WITA tertentu). Per seri: sakelar di kartu seri.
- **Realtime ⚠️ di cek setup**: dashboard tetap berjalan dan memperbarui data otomatis tiap 30 detik.
- **Project Supabase gratis** di-pause kalau ±7 hari tidak ada aktivitas (misalnya jauh sebelum pendaftaran dibuka). Data tetap aman; buka dashboard Supabase → pilih project → **Resume project**. Selama pendaftaran berjalan, kunjungan peserta membuatnya tetap aktif.
- **Ganti versi supabase-js**: di `index.html` ada kode `SRI_SUPABASE` (sidik jari keamanan file). Kalau nomor versinya diganti, sidik jari itu harus diperbarui juga.
