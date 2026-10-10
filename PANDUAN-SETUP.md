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

## Cabang `multi-event` (DEMO)

Cabang ini berisi **demo** sistem multi-event. Selama `MULTI_EVENT_DEMO: true` di `CONFIG`, halaman selalu memakai data contoh di browser dan **tidak** tersambung ke Supabase. Jangan online-kan cabang ini sebagai pengganti `main`.

- `#` → halaman depan semua event (poster tiket untuk event berlangsung & ≤ 2 minggu, kalender untuk event yang masih jauh, daftar event selesai)
- `#panitia` → ruang panitia (super admin: semua event, buat event, akses panitia; panitia: hanya event yang ditugaskan)
- `#e/<kode-event>` → halaman peserta event; `#e/<kode-event>/admin` → dashboard event

Cadangan sistem satu-event: cabang `sebelum-multi-event`. Cadangan data Supabase: jalankan `cadangan-sebelum-multi-event.sql` sebelum memasang versi multi-event.

---

## Pindah ke versi 2 (Jadwal Terbang)

Versi 2 mengubah cara kerja seri: jadwal disusun sebagai **Hari → Seri (jam terbang) → Grup A, B, C** (satu jenis layangan per grup, 25 kotak per baris), dan **nomor layangan diisi peserta sendiri** (unik per jenis).

Lakukan **bersamaan**, karena database versi 2 tidak cocok dengan halaman versi lama:

1. Jalankan `setup.sql` versi 2 di Supabase (SQL Editor → paste seluruh isi → Run). Data pendaftaran lama **tidak dihapus**.
2. Segera online-kan `index.html` versi 2 (gabungkan cabang `jadwal-terbang` ke `main`, atau upload ulang ke Cloudflare).
3. Dashboard → **Jadwal Terbang** → buat hari, seri, dan grup. Formulir peserta baru menampilkan jenis & grup setelah jadwal dibuat.
4. Seri dari versi lama muncul di bagian **Seri lama** pada halaman Jadwal Terbang. Pendaftarnya tetap tercatat; pindahkan lewat **Ubah data** bila perlu, lalu hapus seri lama yang sudah kosong.

Versi sebelumnya tersimpan di cabang GitHub `sistem-lama`.

---

## 0. Coba dulu (mode demo, 1 menit)

Double-click `index.html`. Selama `SUPABASE_URL` dan `SUPABASE_KEY` masih kosong, aplikasi berjalan dalam **MODE DEMO**: data hanya tersimpan di browser itu dan sudah berisi data contoh (jadwal "Hari Minggu" dengan Seri I–III).

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
   - Email: harus sama dengan email admin di BAGIAN 10 `setup.sql`
   - Password: buat password yang kuat (jangan ditulis di file yang di-upload ke GitHub)
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

1. Dashboard → **Pengaturan**: nama event, penyelenggara, lokasi, nomor WA panitia, info & ketentuan, **rekening pembayaran**, template pesan WA.
   Panel **Tampilan halaman peserta**: unggah/ganti/hapus **logo** dan **gambar latar** bagian atas halaman pendaftaran (JPG, PNG, atau WebP; otomatis diperkecil). Kosongkan untuk memakai tampilan bawaan.
2. **Jadwal Terbang** (database awalnya kosong):
   - **Tambah hari** → pilih tanggal (nama "Hari Minggu" dst terisi otomatis), sekalian dibuatkan Seri I.
   - Tombol **✎** di kolom seri → isi jam terbang. Tombol **+ Seri** untuk Seri II, III, dst.
   - **+ Grup** → ketik jenis layangan (pilih dari daftar atau ketik jenis baru). Jenis baru langsung ditanyakan **harganya**. Atur jumlah kotak (bawaan 50 = 2 baris × 25).
   - Klik **kotak kosong** untuk menutupnya (hitam), klik lagi untuk membuka. Kotak tertutup mengurangi kuota grup. Kotak yang sudah terisi peserta tidak bisa ditutup.
   - Klik **nama jenis** di tabel untuk mengubah grup (jenis, huruf, jumlah kotak, buka/tutup grup, hapus).
   - Tombol **Cetak** di samping nama hari mencetak tabel jadwal (A4 mendatar) berisi nomor layangan yang sudah terkonfirmasi.
3. **Jenis Layangan**: ubah nama & harga, atau tutup jenis. Jenis tampil di formulir bila aktif dan punya grup yang dibuka di jadwal.
4. Uji coba: daftar 1–2 kali dari HP → verifikasi di dashboard → kirim WA ke nomor sendiri.
5. Bersihkan data uji: Pengaturan → Zona berbahaya → **Hapus semua pendaftaran** (semua kotak di jadwal kembali kosong).
6. Bagikan link: Pengaturan → Link & berbagi → **Bagikan via WA**.

---

## Alur kerja harian

1. Peserta mengisi 3 langkah: **Data (jenis, seri & grup, nomor layangan, sekha) → Konfirmasi (tampil biaya & rekening) → Upload bukti transfer**. Status awal *Menunggu*, dan kotak di jadwal langsung terpakai (warna kuning).
2. Dashboard → **Verifikasi**: cocokkan bukti transfer dengan tagihan → **Konfirmasi pembayaran** → nomor layangan tampil di tabel jadwal.
3. Klik **Kirim WA konfirmasi** → WhatsApp terbuka dengan pesan sudah terisi, termasuk **link pribadi** peserta (`…/#tiket/KODE`) → tekan Kirim → kembali ke dashboard → **Berikutnya**.
   - Peserta membuka link itu → melihat nomor layangan & jadwal → **Unduh PDF konfirmasi** (A5: logo, nomor, data sekha, jadwal terbang).
   - Link hanya berlaku untuk pendaftaran terkonfirmasi. PDF dibuat di HP peserta, tidak disimpan di server.
   - Template WA lama otomatis ditambahi link di akhir pesan; atur posisinya dengan `{link_konfirmasi}` di Pengaturan → Pesan WhatsApp.
   - Di **Tindakan lain** ada **Salin link PDF**, **Unduh PDF**, dan **Kirim PDF sebagai lampiran**.
4. Bukti bermasalah → **Tolak** + alasan → **Kirim WA penolakan**. Kotak dan nomor layangannya dilepas otomatis.
5. Peserta bayar tunai di tempat → Pendaftaran → **Tambah manual**.
6. Spam/pendaftaran palsu → filter *Menunggu* → **Tolak massal…**
7. Hari-H → Jadwal Terbang → **Cetak** (tabel per hari) atau klik nama jenis → **Cetak daftar** (daftar peserta per grup + kolom hadir). Rekap lengkap → Pendaftaran → **Excel**.

## Aturan yang dijaga otomatis oleh database

- **Kuota per grup** = jumlah kotak dikurangi kotak yang ditutup; dihitung dari pendaftaran *menunggu + terkonfirmasi*. Aman walau banyak orang mendaftar bersamaan — tiap peserta mendapat kotak sendiri, berurutan dari kotak 1.
- **Nomor layangan** diisi peserta (angka, maks 6 digit) dan tidak boleh sama dengan peserta lain **di jenis yang sama**. Nomor dari pendaftaran yang ditolak boleh dipakai lagi.
- **Nama, tanggal & jam grup** mengikuti hari dan seri; mengubah jam seri langsung memperbarui semua grup di dalamnya.
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

**Bucket logo & gambar latar** (kalau baris "Bucket logo & latar" ❌): Storage → New bucket → Name `lomba-media` · Public: **on** · batas 5 MB · tipe `image/jpeg, image/png, image/webp`. Lalu buat 3 policy untuk role authenticated dengan syarat `bucket_id = 'lomba-media' and (select public.lomba_is_admin())`: `lomba_media_admin_baca` (SELECT), `lomba_media_admin_upload` (INSERT), `lomba_media_admin_hapus` (DELETE).

## Lampiran B — Tanya jawab

- **Tambah admin lain**: SQL Editor → `insert into lomba_admin (email) values ('email@contoh.com');` lalu buat user-nya di Authentication (Auto Confirm User).
- **Lupa password admin**: Authentication → Users → pilih user → kirim reset password, atau hapus & buat ulang user dengan email yang sama.
- **Menutup pendaftaran**: Pengaturan → Status pendaftaran (manual, atau otomatis pada tanggal & jam WITA tertentu). Per grup: klik nama jenis di Jadwal Terbang → matikan *Grup ini dibuka*. Per jenis: menu Jenis Layangan.
- **Realtime ⚠️ di cek setup**: dashboard tetap berjalan dan memperbarui data otomatis tiap 30 detik.
- **Project Supabase gratis** di-pause kalau ±7 hari tidak ada aktivitas (misalnya jauh sebelum pendaftaran dibuka). Data tetap aman; buka dashboard Supabase → pilih project → **Resume project**. Selama pendaftaran berjalan, kunjungan peserta membuatnya tetap aktif.
- **Ganti versi supabase-js**: di `index.html` ada kode `SRI_SUPABASE` (sidik jari keamanan file). Kalau nomor versinya diganti, sidik jari itu harus diperbarui juga.
