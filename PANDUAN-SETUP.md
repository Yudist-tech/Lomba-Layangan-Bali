# Panduan Setup — Sistem Pendaftaran Lomba Layangan

Isi folder:

| File | Fungsi |
|---|---|
| `index.html` | Aplikasi lengkap dalam 1 file: halaman peserta + dashboard panitia |
| `setup.sql` | Dijalankan **sekali** di Supabase (tabel, keamanan, penyimpanan bukti transfer) |
| `multi-event.sql` | Pembaruan ke multi-event, dijalankan setelah `setup.sql` (lihat *Pindah ke MULTI-EVENT*) |
| `PANDUAN-SETUP.md` | File ini |

Alamat halaman (setelah online):

- Peserta: `https://NAMA-PROJECT.pages.dev` → tab **Daftar**, **Jadwal**, **Cek Status**
- Dashboard panitia: `https://NAMA-PROJECT.pages.dev/#admin` (versi multi-event: `#panitia`)

---

## Pindah ke MULTI-EVENT (versi 3)

Versi 3 membuat satu situs berisi banyak event: halaman depan semua event, ruang panitia untuk super admin, dan dashboard per event.
Data yang sudah ada otomatis menjadi **event pertama**, dan tidak ada yang dihapus.

| File | Fungsi |
|---|---|
| `cadangan-sebelum-multi-event.sql` | Menyalin semua data ke skema cadangan (jalankan **pertama**) |
| `multi-event.sql` | Mengubah database menjadi multi-event (jalankan **kedua**) |
| `index.html` (cabang `multi-event`) | Halaman versi multi-event |

### Langkah pemasangan (±15 menit, sebaiknya saat sepi pendaftar)

1. **Cadangkan data.** SQL Editor → New query → paste seluruh `cadangan-sebelum-multi-event.sql` → Run.
   Angka kolom **asli** dan **cadangan** harus sama di setiap baris.
2. **Ubah database.** SQL Editor → New query → paste seluruh `multi-event.sql` → Run.
   Tabel *cek multi-event* di bawah editor: keenam baris harus ✅. Baris 3 menunjukkan jumlah pendaftaran, dan angkanya harus sama dengan sebelumnya.
   Situs yang sedang online **tetap berjalan normal** setelah langkah ini (memakai event pertama), jadi tidak perlu terburu-buru.
3. **Atur login lewat email** (supaya undangan admin event bisa terkirim):
   - **Authentication → URL Configuration**:
     - **Site URL** = alamat situs, contoh `https://lomba-layangan.pages.dev`.
     - **Redirect URLs** → Add URL → alamat yang sama.
   - **Authentication → Sign In / Providers → Email**:
     - nyalakan **Allow new users to sign up**. Ini dibutuhkan agar undangan bisa membuatkan akun untuk panitia baru. Akun yang tidak ditugaskan ke event mana pun **tidak bisa melihat apa pun**.
     - Biarkan **Confirm email** menyala.
   - (Opsional) **Authentication → Emails → Magic Link**: ubah subjek menjadi misalnya `Link masuk Panitia Lomba Layangan`.
   - Catatan: pengiriman email bawaan Supabase dibatasi hanya beberapa email per jam. Kalau perlu mengundang banyak panitia sekaligus, pasang SMTP sendiri di **Authentication → Emails → SMTP Settings**, atau kirim ulang undangan beberapa saat kemudian (tombol ✈ di daftar admin event).
4. **Online-kan halaman baru.** Gabungkan cabang `multi-event` ke `main` (Cloudflare otomatis memperbarui), atau upload `index.html` dari cabang `multi-event` ke Cloudflare.
5. **Periksa:**
   - Buka halaman depan → event pertama tampil.
   - Klik **Masuk panitia** → login dengan akun admin yang lama. Anda masuk sebagai **super admin**, dengan tab *Event*, *Admin event*, dan *Pengaturan situs*.
   - Buka **Dashboard** event pertama → jumlah pendaftar sama seperti sebelumnya.
   - Tombol ⚙ di kartu event → ubah **kode alamat** event pertama bila mau, lalu tambahkan email admin event (undangan terkirim otomatis).

### Alamat baru

- Halaman depan semua event: `https://NAMA.pages.dev`
- Ruang panitia: `https://NAMA.pages.dev/#panitia`
- Halaman peserta satu event: `https://NAMA.pages.dev/#e/<kode-event>` (Jadwal: `/jadwal`, Cek Status: `/cek`)
- Dashboard satu event: `https://NAMA.pages.dev/#e/<kode-event>/admin`

Link lama tetap aman:
- `#tiket/KODE`, yaitu link PDF yang sudah terkirim lewat WA, otomatis dibuka di event yang benar.
- `#admin` diarahkan ke ruang panitia.
- `#daftar` diarahkan ke halaman depan.

### Peran

- **Super admin** adalah email yang ada di tabel `lomba_admin`. Super admin bisa membuka semua event, membuat event, memberi atau mencabut akses admin event, mengatur halaman depan, serta mengubah nama, tanggal & lokasi event.
  Semua admin lama otomatis menjadi super admin. Untuk menjadikan seseorang admin event saja:
  1. hapus emailnya dari super admin lewat SQL: `delete from lomba_admin where email = 'email@contoh.com';`
  2. tambahkan emailnya lewat ⚙ di kartu event.
- **Admin event** hanya bisa membuka dashboard event yang ditugaskan, dan tidak bisa mengubah nama, tanggal & lokasi event. Saat ditambahkan, admin event menerima email undangan. Setelah klik link di email itu, ia diminta membuat password sendiri. Kalau lupa password, gunakan **Kirim link masuk ke email** di halaman login.

### Kembali ke versi lama (bila perlu)

Upload `index.html` dari cabang `sebelum-multi-event` ke Cloudflare. Versi lama tetap berjalan dengan database baru dan menampilkan event pertama. Event lain hanya tidak terlihat di versi lama.
**Jangan** menjalankan `setup.sql` lagi setelah pindah ke multi-event. File itu sudah diberi pengaman yang akan menolak dijalankan.
Data sebelum pembaruan tetap tersimpan di skema `cadangan_sebelum_multi_event` (Table Editor → pilih schema tersebut).

### Mode demo

Kalau `SUPABASE_URL`/`SUPABASE_KEY` dikosongkan, atau `MULTI_EVENT_DEMO: true` di `CONFIG`, halaman berjalan dengan data contoh di browser. Masuk cepat tersedia sebagai super admin dan panitia contoh.

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
5. **Authentication → Sign In / Providers** → untuk versi satu event: matikan **Allow new users to sign up**. Untuk versi multi-event: nyalakan (lihat *Pindah ke MULTI-EVENT* langkah 3).
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
8. Cari bukti yang dipakai ulang → Pendaftaran → **Periksa bukti** (lihat bagian di bawah).

## Login panitia dengan ID (tanpa email)

Pasang sekali: jalankan **`login-id.sql`** di SQL Editor (hasil 3 ✅).

1. Super admin → Ruang panitia → kartu event → **Atur** → bagian **Tambah panitia baru** → ketik **nama lengkap** (mis. `I Made Sudarma`) → **Buat ID**. Sistem membuat ID dari **huruf pertama setiap kata nama** (awalan I/Ni kadang ikut, kadang dilewati — acak; butuh **`id-awalan.sql`**); bila kurang dari 5 huruf, ditambah huruf acak dari dalam nama dengan urutan tetap, lalu **3 angka acak tanpa pola** (bukan 000, 111, 123, 321, …). Contoh: *I Made Darma Wiguna Artha* → `Mdwia587` atau `Imdwa587`. Huruf besar/kecil tidak berpengaruh saat login. Butuh **`login-nama.sql`** (jalankan sekali setelah `login-id.sql`, hasil 3 ✅).
2. Muncul ID + password acak. Tekan **Kirim lewat WA** atau **Salin**. Password hanya ditampilkan sekali.
3. Panitia membuka `…/#panitia`, isi kolom **Email atau ID** dengan ID-nya, lalu password.

- ID: huruf kecil, angka, titik, strip, garis bawah; 3–30 karakter; huruf besar otomatis jadi kecil.
- Ganti password sendiri → tombol **Ganti password** (ikon gembok) di ruang panitia atau di sidebar dashboard event → isi password lama + password baru.
- **Hapus akun** (ikon tempat sampah di Atur event, atau tombol di tab Admin event) → ID, password, nama & semua akses dihapus permanen; ID itu tidak bisa login lagi. Data pendaftaran tetap aman. Butuh **`hapus-akun.sql`** (jalankan sekali). Untuk orang yang sama, buat ID baru lewat **Tambah panitia baru**. Akun super admin & akun Anda sendiri tidak bisa dihapus.
- Lupa password → super admin → tab **Admin event** (atau Atur event) → **Reset password** → password baru tampil untuk dikirim.
- ID yang sudah ada bisa ditambahkan ke event lain lewat **Tambahkan ID yang sudah ada** di jendela Atur event; password lamanya tetap.
- **Super admin juga mau login dengan ID?** Buka `super-admin-id.sql`, ganti ID, password, dan email super admin Anda, lalu Run sekali di SQL Editor. Login email super admin tetap berlaku.
- Akun email lama tetap bisa login seperti biasa. Di balik layar ID disimpan sebagai `<id>@id.panitia.lomba` (tidak pernah dikirimi email).

## Riwayat & kinerja panitia

Pasang sekali: jalankan **`riwayat.sql`** di SQL Editor (hasil 3 ✅).

- Database mencatat **otomatis** akun yang mengonfirmasi, menolak, mengirim WA, menambah, mengubah, atau menghapus pendaftaran — tidak bisa dipalsukan dari aplikasi.
- **Panel detail pendaftaran → Riwayat**: mis. *Dikonfirmasi oleh Mdwia587 (I Made Darma Wiguna Artha) · 14 Okt 08.52*, *Data diubah: nomor layangan 901 → 902*.
- **Ringkasan → Kinerja panitia**: jumlah dikonfirmasi, ditolak, dan WA dikirim per panitia.
- **Excel**: kolom *Dikonfirmasi oleh*, *Ditolak oleh*, *WA dikirim oleh*.
- Pendaftaran yang dikonfirmasi sebelum `riwayat.sql` dipasang ditandai *sebelum pencatatan aktif*.

## Bukti Transfer Sama & Bukti Transfer Mirip

- **Bukti Transfer Sama** (otomatis): file gambar yang diunggah **persis sama** di lebih dari 1 pendaftaran. Dikelompokkan *Bukti A, Bukti B, …* dengan warna sendiri. Yang dibandingkan hanya file gambarnya — nama sekha, jenis, atau biaya tidak berpengaruh. Dobel belum tentu curang: satu transfer bisa memang untuk beberapa layangan, jadi cek apakah nominal di bukti cukup untuk total tagihan kelompok.
- **Bukti Transfer Mirip** (perlu klik **Periksa bukti**): dashboard membaca tulisan di gambar bukti (nominal, tanggal & jam, nama pengirim). Pendaftaran ditandai *Mirip 1, Mirip 2, …* bila **nama pengirim sama + nominal sama + waktu di bukti selisih ≤ 1 menit**. Ini menangkap bukti yang sama walau filenya berbeda (screenshot ulang, dikirim ulang lewat WhatsApp, dipotong).
  - Pasang sekali: jalankan **`bukti-mirip.sql`** di SQL Editor (hasil 2 ✅).
  - **Otomatis**: selama dashboard terbuka, bukti yang belum diperiksa dibaca sendiri di latar belakang — saat dashboard dibuka dan setiap ada pendaftaran baru. Tombol berubah menjadi *Memeriksa bukti 3/10*, dan muncul pemberitahuan bila ada Bukti Transfer Mirip baru.
  - Pengaturan otomatis **per perangkat** (centang *Periksa otomatis di perangkat ini* di jendela Periksa bukti). Bawaan: aktif di laptop/komputer, mati di HP (hemat kuota & baterai). Cukup satu panitia yang membiarkan dashboard terbuka di laptop.
  - Pembacaan berjalan di browser panitia, jadi **tidak berjalan bila tidak ada dashboard yang terbuka**; bukti yang masuk saat itu dibaca begitu dashboard dibuka lagi.
  - Tombol **Periksa bukti** juga bisa diklik manual; menunjukkan jumlah bukti baru yang belum diperiksa. Tiap gambar cukup dibaca sekali; hasilnya tersimpan di database.
  - Pertama kali, browser mengunduh pembaca teks (±5 MB). Lebih nyaman dijalankan di laptop; ±1–3 detik per gambar.
  - Gambar buram/terpotong yang tidak terbaca dihitung sebagai *tidak terbaca otomatis* — cek manual.
  - Tanda *mirip* adalah petunjuk, bukan keputusan: tetap buka kedua bukti dan cocokkan sebelum menolak.

### Tab Terbaru & Selesai

Pasang sekali: jalankan **`bukti-selesai.sql`** di SQL Editor (hasil 2 ✅). Sebelum dipasang, dashboard menampilkan catatan untuk menjalankannya.

- Di filter **Bukti Transfer Sama** dan **Bukti Transfer Mirip** ada tab **Terbaru** (perlu dicek) dan **Selesai** (sudah dicek). Angka merah di tombol filter = jumlah kelompok di Terbaru.
- Setelah mengecek satu kelompok, klik **Tandai selesai** → kelompok pindah ke Selesai. Tercatat siapa (ID panitia) dan kapan.
- Bila kemudian masuk pendaftaran baru dengan bukti yang sama/mirip, **seluruh kelompok kembali ke Terbaru**: pendaftaran baru diberi label **BARU** dan ada catatan siapa yang sebelumnya menandai selesai. Periksa ulang semuanya, lalu tandai selesai lagi.
- **Buka lagi** mengembalikan kelompok dari Selesai ke Terbaru.
- Semua panitia event bisa menandai & membuka lagi.
- Di **Ringkasan** ada satu pengingat *"N kelompok bukti perlu dicek"* (Sama + Mirip di tab Terbaru). Klik **Sama** / **Mirip** untuk langsung membuka filternya; keterangan muncul bila ada kelompok yang kembali karena pendaftaran baru. Pengingat hilang sendiri setelah semua ditandai selesai.

## Tema event & penyelenggara

- **Tema event** (opsional): Pengaturan → Informasi event → *Tema event*. Tampil di halaman peserta tepat di bawah nama event, huruf miring dalam tanda kutip. Kosong = tidak tampil. Pasang sekali: jalankan **`tema-event.sql`** (hasil 2 ✅).
- **Penyelenggara** hanya tampil di halaman peserta bila diisi. Kosongkan kolomnya bila tidak ingin ditampilkan (teks bawaan "Panitia Lomba Layangan" juga dianggap belum diisi).

## Penilaian & juara

Pasang sekali: jalankan **`juara.sql`** di Supabase → SQL Editor (hasil **4 ✅**). Aman dijalankan ulang.

**Penilaian** (menu *Penilaian* di dasbor panitia, semua panitia event bisa mengisi):
1. Pilih jenis layangan di atas tabel.
2. Isi nama juri di kepala kolom (bawaan 3 juri; **+ Juri** untuk menambah, juri sama untuk semua jenis).
3. Semua layangan **terkonfirmasi** di jenis itu langsung bisa dinilai. Tabel menampilkan **15 teratas** (urut peringkat, yang belum dinilai di bawah); sisanya disembunyikan (ada tautan *Tampilkan semua*).
4. Ketik **nomor layangan** di kotak cari → hanya nomor itu yang tampil → **Enter** → isi nilai Juri 1 → **Enter** → Juri 2 → … Setelah juri terakhir kursor kembali ke kotak cari (angka lama terpilih), tinggal ketik nomor berikutnya.
5. Nilai angka bulat 0–100 (batas atas bisa diubah lewat tombol **Nilai 1–100**). Total & peringkat dihitung otomatis.
6. **Nilai sama** → tekan **Naikkan** pada layangan yang ingin ditaruh di atas.
7. **DQ** wajib dengan alasan; peringkat di bawahnya otomatis naik. ✎ untuk catatan.

**Juara (per jenis)**: tekan **Jadikan juara** (peringkat 1–3 = Juara, berikutnya Harapan; bawaan 6 harapan, bisa ditambah) → cek daftar → **Umumkan juara <jenis>**. Tiap jenis diumumkan sendiri-sendiri, jadi jenis yang selesai dinilai lebih dulu bisa langsung diumumkan; jenis yang sudah diumumkan diberi 🏆 di pilihan jenis. Selama masih draf ada tombol **Batalkan draf** (nilai juri tidak terhapus). Di halaman peserta (tab *Juara*, muncul mulai hari terakhir event) jenis yang belum diumumkan bertanda "segera" dan menampilkan "Juri & panitia masih berdiskusi…". Begitu satu jenis diumumkan, halaman semua event menampilkan tombol **🏆 Lihat juara**. Publik hanya melihat nomor, sekha dan banjar. Tombol WA ucapan selamat bersifat opsional. Pengumuman bisa ditarik kembali per jenis (data tidak terhapus).

## Aturan yang dijaga otomatis oleh database

- **Kuota per grup** = jumlah kotak dikurangi kotak yang ditutup; dihitung dari pendaftaran *menunggu + terkonfirmasi*. Aman walau banyak orang mendaftar bersamaan — tiap peserta mendapat kotak sendiri, berurutan dari kotak 1.
- **Nomor layangan** diisi peserta (angka, maks 6 digit) dan tidak boleh sama dengan peserta lain **di jenis yang sama**. Nomor dari pendaftaran yang ditolak boleh dipakai lagi.
- **Nomor minimal 2 angka**: 1 → 01, 2 → 02 … 9 → 09 untuk semua jenis (pasang sekali: jalankan **`nomor-2-digit.sql`**, hasil 2 ✅ — nomor peserta yang sudah terdaftar ikut dirapikan). Rentang yang ditulis 001 tetap 3 angka.
- **Nama, tanggal & jam grup** mengikuti hari dan seri; mengubah jam seri langsung memperbarui semua grup di dalamnya.
- **Harga** tersimpan saat mendaftar. Mengubah harga hanya berlaku untuk pendaftaran baru; peserta yang sedang membayar saat harga berubah diminta cek ulang.
- **Bukti transfer** wajib benar-benar terunggah; satu bukti yang dipakai >1 pendaftaran ditandai *Bukti Transfer Sama*.
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

- **Tambah admin lain**: versi multi-event → ruang panitia → ⚙ di kartu event → tambah email (undangan terkirim otomatis). Super admin tambahan: SQL Editor → `insert into lomba_admin (email) values ('email@contoh.com');`.
- **Lupa password admin**: Authentication → Users → pilih user → kirim reset password, atau hapus & buat ulang user dengan email yang sama.
- **Menutup pendaftaran**: Pengaturan → Status pendaftaran (manual, atau otomatis pada tanggal & jam WITA tertentu). Per grup: klik nama jenis di Jadwal Terbang → matikan *Grup ini dibuka*. Per jenis: menu Jenis Layangan.
- **Realtime ⚠️ di cek setup**: dashboard tetap berjalan dan memperbarui data otomatis tiap 30 detik.
- **Project Supabase gratis** di-pause kalau ±7 hari tidak ada aktivitas (misalnya jauh sebelum pendaftaran dibuka). Data tetap aman; buka dashboard Supabase → pilih project → **Resume project**. Selama pendaftaran berjalan, kunjungan peserta membuatnya tetap aktif.
- **Ganti versi supabase-js**: di `index.html` ada kode `SRI_SUPABASE` (sidik jari keamanan file). Kalau nomor versinya diganti, sidik jari itu harus diperbarui juga.
