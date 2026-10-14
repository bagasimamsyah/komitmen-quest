# Komitmen Quest: panduan memasang papan norma kelas

Papan norma menampilkan pilihan norma semua peserta sebagai *word cloud* di layar fasilitator. Norma yang paling banyak dipilih tampil paling besar. Untuk itu dibutuhkan 3 layanan yang sudah Anda punya: **Supabase**, **GitHub**, dan **Vercel**.

## Langkah 1: Pasang database di Supabase (sekali saja)
1. Buka supabase.com, lalu masuk ke proyek yang sama dengan BLC Team Race.
2. Buka menu **SQL Editor**, lalu klik **New query**.
3. Buka file `supabase/komitmen-quest.sql` dengan Notepad. Tekan **Ctrl+A**, lalu **Ctrl+C**.
4. Tempel ke Supabase (**Ctrl+V**), lalu klik **Run**. Pastikan muncul *Success*.

File ini tidak mengubah apa pun milik BLC Team Race. Semua tabelnya diberi awalan `kq_`.

## Langkah 2: Isi file config.js
1. Buka `config.js` dengan Notepad.
2. Isi di antara tanda kutip:
   - `SUPABASE_URL`: Project URL, contoh `https://jpfdkgxmfmudrpoueojv.supabase.co`
   - `SUPABASE_KEY`: kunci `sb_publishable_...` (salin dengan ikon salin di Supabase)
3. Simpan file (**Ctrl+S**).

Jangan memakai kunci *service_role* atau *secret*.

## Langkah 3: Unggah ke GitHub
1. Buka github.com, klik **+**, lalu **New repository**.
2. Beri nama `komitmen-quest`, lalu klik **Create repository**.
3. Klik **uploading an existing file**.
4. Seret **isi** folder ini, yaitu `index.html`, `config.js`, folder `vendor`, dan seterusnya, ke halaman GitHub.
5. Klik **Commit changes**.

## Langkah 4: Tayangkan dengan Vercel
1. Buka vercel.com, lalu pilih **Add New…** → **Project**.
2. Pilih repositori `komitmen-quest` → **Import**.
3. Pada *Framework Preset*, pilih **Other**, lalu klik **Deploy**.
4. Anda mendapat tautan, misalnya `komitmen-quest.vercel.app`.

Langkah ini tidak memerlukan Environment Variables, karena kuncinya sudah ada di `config.js`.

## Cara memakai di kelas
1. **Fasilitator:**
   - Buka tautan Vercel, lalu klik **Panduan fasilitator**.
   - Di bagian **Papan Norma Kelas**, isi nama kelas, lalu klik **Buat kelas baru**.
   - Papan langsung terbuka. Bagikan layarnya di Zoom.
2. **Peserta:**
   - Scan kode QR di papan, atau buka tautan yang tampil di papan. Kode kelas akan terisi otomatis.
   - Bisa juga mengetik kode kelas secara manual di halaman awal.
3. Setelah peserta menyelesaikan Level 6, norma pilihan mereka **otomatis masuk ke papan**. Papan diperbarui setiap 3 detik.
4. Di samping papan ada tiga bagian:
   - **Kandidat kontrak belajar** (3 norma teratas, lengkap dengan persentase)
   - **Karakter belajar kelas**
   - **Janji peserta**, yang bisa ditampilkan atau disembunyikan

## Tombol di papan (hanya muncul di perangkat pembuat kelas)
| Tombol | Fungsi |
|---|---|
| Tutup / Buka pengisian | Menghentikan atau membuka kiriman baru |
| Moderasi kata | Klik sebuah kata di papan untuk menyembunyikannya, misalnya usulan yang kurang pantas |
| Tampilkan kata tersembunyi | Mengembalikan semua kata yang disembunyikan |
| Reset jawaban | Menghapus semua jawaban kelas ini. Klik 2 kali untuk konfirmasi |
| Salin tautan kendali | Membuka papan dengan tombol pengatur di laptop lain. **Jangan dibagikan ke peserta** |

## Catatan
- Setiap HP dihitung satu suara. Jika peserta mengirim ulang, pilihan lamanya diganti, bukan ditambah.
- Nama peserta tidak ditampilkan di papan.
- Peserta dapat menambahkan satu "Norma lain…" usulan sendiri. Ejaan yang sama, termasuk perbedaan huruf besar/kecil atau spasi, dihitung sebagai satu kata.
- Jika `config.js` dikosongkan, game tetap bisa dimainkan tanpa papan kelas.
