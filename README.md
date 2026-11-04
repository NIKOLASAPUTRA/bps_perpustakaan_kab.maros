# Perpustakaan Digital BPS Kabupaten Maros

Proyek ini merupakan pengembangan dari `DigiLib_AI_Supabase_Starter.zip` menjadi portal perpustakaan digital BPS Kabupaten Maros. Teknologi utama dipertahankan: React, TypeScript, Vite, dan Supabase.

## Menjalankan di Windows PowerShell

```powershell
cd "$HOME\Downloads\DigiLib_AI_Supabase_Starter\digilib-ai-starter"
npm install
Copy-Item .env.example .env.local
npm run dev
```

Buka alamat lokal yang ditampilkan Vite, biasanya `http://localhost:5173`.

## Menghubungkan Supabase

1. Buat project di Supabase.
2. Buka **Project Settings → API**.
3. Salin Project URL dan publishable/anon key ke `.env.local`.
4. Buka **SQL Editor** dan jalankan seluruh `supabase/schema.sql`.
5. Daftarkan akun melalui tombol **Masuk → Daftar**.
6. Tetapkan akun pengelola pertama sebagai admin dari SQL Editor:

```sql
update public.profiles
set role = 'admin'
where id = (select id from auth.users where email = 'EMAIL_ADMIN');
```

Ganti `EMAIL_ADMIN` dengan email admin. Jangan mengubah peran lewat browser dan jangan pernah memasukkan `service_role` key ke frontend.

Contoh `.env.local`:

```env
VITE_SUPABASE_URL=https://PROJECT_ID.supabase.co
VITE_SUPABASE_ANON_KEY=SUPABASE_PUBLISHABLE_OR_ANON_KEY
```

## Yang sudah tersedia pada tahap ini

- Identitas Perpustakaan Digital BPS Kabupaten Maros.
- Layout sidebar dan navigasi responsif.
- Beranda, katalog, kategori, publikasi, buku terbaru, favorit, AI Asisten, riwayat, peminjaman, anggota, dan pengaturan.
- Pencarian katalog dan filter kategori.
- Login dan pendaftaran melalui Supabase Auth.
- Profil dengan peran `admin`, `staff`, dan `member`.
- Membaca koleksi yang sudah dipublikasikan dari tabel `books`.
- Favorit tersimpan pada tabel `favorites`.
- Unggah PDF/EPUB untuk admin/petugas ke bucket privat sebagai draft.
- Skema awal Supabase, kategori awal, pgvector, RLS, dan aturan Storage.

## Fitur yang masih memerlukan pengembangan backend

Fitur berikut belum boleh dianggap aktif: reader PDF/EPUB lengkap, bookmark/progress membaca, AI RAG yang benar-benar mengekstrak dokumen dan memberi sitasi halaman, OCR, barcode kamera, transaksi peminjaman/pengembalian, statistik dashboard admin, notifikasi, dan audit log. AI Asisten pada UI saat ini menjelaskan status persiapan dan tidak membuat jawaban statistik palsu.

Untuk AI RAG diperlukan backend/Edge Functions atau worker yang aman untuk ekstraksi PDF/EPUB, chunking, embedding, pencarian pgvector, dan pemanggilan model AI. Simpan API key model hanya di server/Edge Function, bukan di variabel `VITE_`.

## Catatan keamanan

- File publikasi disimpan pada bucket `library-files` yang privat.
- Pengunjung hanya dapat membaca metadata buku yang telah dipublikasikan.
- Pengelolaan koleksi dan file dibatasi pada peran admin/petugas melalui RLS.
- Role awal setiap akun adalah `member`; admin pertama ditetapkan manual melalui SQL.
- Jangan unggah data mikro atau dokumen internal yang tidak diizinkan untuk dibagikan.
