-- PERPUSTAKAAN DIGITAL BPS KABUPATEN MAROS
-- Jalankan di Supabase SQL Editor pada project yang benar.
-- Jangan masukkan service_role key ke aplikasi frontend.
create extension if not exists pgcrypto;
create extension if not exists vector;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  role text not null default 'member' check (role in ('admin','staff','member')),
  member_code text unique,
  created_at timestamptz not null default now()
);
create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(), name text not null unique,
  slug text not null unique, description text, created_at timestamptz not null default now()
);
create table if not exists public.books (
  id uuid primary key default gen_random_uuid(), title text not null,
  author text, publisher text, year_published integer, description text,
  cover_url text, category text, category_id uuid references public.categories(id) on delete set null,
  file_path text, file_type text check (file_type is null or upper(file_type) in ('PDF','EPUB')),
  isbn text, page_count integer, barcode text unique,
  collection_type text not null default 'digital' check (collection_type in ('digital','physical')),
  is_published boolean not null default false,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.books add column if not exists publisher text;
alter table public.books add column if not exists year_published integer;
alter table public.books add column if not exists page_count integer;
alter table public.books add column if not exists updated_at timestamptz not null default now();

create table if not exists public.reading_progress (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  book_id uuid not null references public.books(id) on delete cascade,
  current_page integer not null default 1, updated_at timestamptz not null default now(), unique(user_id,book_id)
);
create table if not exists public.bookmarks (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  book_id uuid not null references public.books(id) on delete cascade, page_number integer not null,
  note text, created_at timestamptz not null default now(), unique(user_id,book_id,page_number)
);
create table if not exists public.favorites (
  user_id uuid not null references auth.users(id) on delete cascade,
  book_id uuid not null references public.books(id) on delete cascade,
  created_at timestamptz not null default now(), primary key(user_id,book_id)
);
create table if not exists public.library_members (
  id uuid primary key default gen_random_uuid(), user_id uuid references auth.users(id) on delete set null,
  member_code text not null unique, full_name text not null, barcode text not null unique,
  status text not null default 'active' check (status in ('active','inactive')), created_at timestamptz not null default now()
);
create table if not exists public.borrowing_records (
  id uuid primary key default gen_random_uuid(), book_id uuid not null references public.books(id),
  member_id uuid not null references public.library_members(id), borrowed_at timestamptz not null default now(),
  due_at timestamptz not null, returned_at timestamptz,
  status text not null default 'borrowed' check (status in ('borrowed','returned','overdue'))
);
create table if not exists public.document_chunks (
  id uuid primary key default gen_random_uuid(), book_id uuid not null references public.books(id) on delete cascade,
  chunk_index integer not null, page_number integer, content text not null,
  embedding vector(1536), created_at timestamptz not null default now(), unique(book_id,chunk_index)
);
create index if not exists document_chunks_embedding_idx on public.document_chunks using ivfflat (embedding vector_cosine_ops) with (lists=100);
create table if not exists public.chat_sessions (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  title text not null default 'Percakapan baru', created_at timestamptz not null default now()
);
create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(), session_id uuid not null references public.chat_sessions(id) on delete cascade,
  role text not null check (role in ('user','assistant')), content text not null,
  citations jsonb not null default '[]'::jsonb, created_at timestamptz not null default now()
);

create or replace function public.current_library_role() returns text
language sql stable security definer set search_path=public
as $$ select coalesce((select role from public.profiles where id=auth.uid()),'member') $$;
create or replace function public.handle_new_library_user() returns trigger
language plpgsql security definer set search_path=public
as $$ begin insert into public.profiles(id,full_name,role) values(new.id,coalesce(new.raw_user_meta_data->>'full_name','Anggota'), 'member') on conflict(id) do nothing; return new; end $$;
drop trigger if exists on_auth_user_created_library on auth.users;
create trigger on_auth_user_created_library after insert on auth.users for each row execute procedure public.handle_new_library_user();

alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.books enable row level security;
alter table public.reading_progress enable row level security;
alter table public.bookmarks enable row level security;
alter table public.favorites enable row level security;
alter table public.library_members enable row level security;
alter table public.borrowing_records enable row level security;
alter table public.document_chunks enable row level security;
alter table public.chat_sessions enable row level security;
alter table public.chat_messages enable row level security;

-- Hapus policy starter lama agar aturan di bawah konsisten saat SQL dijalankan ulang.
drop policy if exists "Published books are readable" on public.books;
drop policy if exists "Categories readable" on public.categories;
drop policy if exists "Own profile readable" on public.profiles;
drop policy if exists "Own profile editable" on public.profiles;
drop policy if exists "Own progress all" on public.reading_progress;
drop policy if exists "Own favorites all" on public.favorites;
drop policy if exists "Own chat sessions" on public.chat_sessions;
drop policy if exists "Own chat messages" on public.chat_messages;
drop policy if exists "Public can read categories" on public.categories;
drop policy if exists "Users read own profile" on public.profiles;
drop policy if exists "Users update own profile name" on public.profiles;
drop policy if exists "Published catalog or managers read books" on public.books;
drop policy if exists "Managers manage books" on public.books;
drop policy if exists "Managers manage categories" on public.categories;
drop policy if exists "Users manage own progress" on public.reading_progress;
drop policy if exists "Users manage own bookmarks" on public.bookmarks;
drop policy if exists "Users manage own favorites" on public.favorites;
drop policy if exists "Managers manage members" on public.library_members;
drop policy if exists "Members read own member card" on public.library_members;
drop policy if exists "Managers manage borrowing" on public.borrowing_records;
drop policy if exists "Members read own borrowing" on public.borrowing_records;
drop policy if exists "Managers manage chunks" on public.document_chunks;
drop policy if exists "Users manage own chat sessions" on public.chat_sessions;
drop policy if exists "Users manage own chat messages" on public.chat_messages;

create policy "Public can read categories" on public.categories for select using (true);
create policy "Managers manage categories" on public.categories for all to authenticated using (public.current_library_role() in ('admin','staff')) with check (public.current_library_role() in ('admin','staff'));
create policy "Users read own profile" on public.profiles for select to authenticated using (auth.uid()=id or public.current_library_role()='admin');
create policy "Users update own profile name" on public.profiles for update to authenticated using (auth.uid()=id) with check (auth.uid()=id and role='member');
create policy "Published catalog or managers read books" on public.books for select using (is_published=true or (auth.role()='authenticated' and public.current_library_role() in ('admin','staff')));
create policy "Managers manage books" on public.books for all to authenticated using (public.current_library_role() in ('admin','staff')) with check (public.current_library_role() in ('admin','staff'));
create policy "Users manage own progress" on public.reading_progress for all to authenticated using (auth.uid()=user_id) with check (auth.uid()=user_id);
create policy "Users manage own bookmarks" on public.bookmarks for all to authenticated using (auth.uid()=user_id) with check (auth.uid()=user_id);
create policy "Users manage own favorites" on public.favorites for all to authenticated using (auth.uid()=user_id) with check (auth.uid()=user_id);
create policy "Managers manage members" on public.library_members for all to authenticated using (public.current_library_role() in ('admin','staff')) with check (public.current_library_role() in ('admin','staff'));
create policy "Members read own member card" on public.library_members for select to authenticated using (user_id=auth.uid());
create policy "Managers manage borrowing" on public.borrowing_records for all to authenticated using (public.current_library_role() in ('admin','staff')) with check (public.current_library_role() in ('admin','staff'));
create policy "Members read own borrowing" on public.borrowing_records for select to authenticated using (exists(select 1 from public.library_members m where m.id=member_id and m.user_id=auth.uid()));
create policy "Managers manage chunks" on public.document_chunks for all to authenticated using (public.current_library_role() in ('admin','staff')) with check (public.current_library_role() in ('admin','staff'));
create policy "Users manage own chat sessions" on public.chat_sessions for all to authenticated using (auth.uid()=user_id) with check (auth.uid()=user_id);
create policy "Users manage own chat messages" on public.chat_messages for all to authenticated using (exists(select 1 from public.chat_sessions s where s.id=session_id and s.user_id=auth.uid())) with check (exists(select 1 from public.chat_sessions s where s.id=session_id and s.user_id=auth.uid()));

insert into public.categories(name,slug) values
('Kabupaten Maros Dalam Angka','kabupaten-maros-dalam-angka'),('Kecamatan Dalam Angka','kecamatan-dalam-angka'),
('Statistik Sosial dan Kependudukan','statistik-sosial-kependudukan'),('Statistik Ekonomi','statistik-ekonomi'),
('Statistik Pertanian','statistik-pertanian'),('Statistik Pendidikan','statistik-pendidikan'),
('Statistik Kesehatan','statistik-kesehatan'),('Statistik Infrastruktur','statistik-infrastruktur'),
('Publikasi BPS','publikasi-bps'),('Laporan dan Dokumen','laporan-dokumen'),('Buku Referensi','buku-referensi')
on conflict(name) do nothing;

insert into storage.buckets(id,name,public) values('library-files','library-files',false) on conflict(id) do update set public=false;
insert into storage.buckets(id,name,public) values('book-covers','book-covers',true) on conflict(id) do nothing;
drop policy if exists "Published file metadata only" on storage.objects;
drop policy if exists "Managers upload library files" on storage.objects;
drop policy if exists "Managers update library files" on storage.objects;
drop policy if exists "Managers delete library files" on storage.objects;
drop policy if exists "Readers access published library files" on storage.objects;
create policy "Managers upload library files" on storage.objects for insert to authenticated with check(bucket_id='library-files' and public.current_library_role() in ('admin','staff'));
create policy "Managers update library files" on storage.objects for update to authenticated using(bucket_id='library-files' and public.current_library_role() in ('admin','staff')) with check(bucket_id='library-files' and public.current_library_role() in ('admin','staff'));
create policy "Managers delete library files" on storage.objects for delete to authenticated using(bucket_id='library-files' and public.current_library_role() in ('admin','staff'));
create policy "Readers access published library files" on storage.objects for select to authenticated using(bucket_id='library-files' and exists(select 1 from public.books b where b.file_path=name and b.is_published=true));

-- Setelah akun admin dibuat melalui menu Daftar, tetapkan perannya secara manual:
-- update public.profiles set role='admin' where id=(select id from auth.users where email='EMAIL_ADMIN');
-- Jangan memberi hak admin melalui metadata yang dikirim dari browser.
