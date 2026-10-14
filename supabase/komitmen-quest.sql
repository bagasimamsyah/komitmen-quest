-- =====================================================================
-- KOMITMEN QUEST — papan norma kelas (word cloud fasilitator)
-- Jalankan SEKALI di Supabase → SQL Editor → New query → Run.
-- Aman dipasang di proyek yang sama dengan BLC Team Race (semua nama diawali kq_).
--
-- Keamanan:
--   * Browser tidak bisa membaca/menulis tabel langsung (RLS aktif, hak tabel dicabut).
--   * Semua akses lewat fungsi RPC di bawah, dengan batas panjang & jumlah isian.
--   * Mengatur kelas (buka/tutup, sembunyikan kata, reset) butuh token admin
--     yang hanya diberikan kepada pembuat kelas.
-- =====================================================================

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.kq_rooms (
  id           uuid primary key default gen_random_uuid(),
  code         text not null unique,
  title        text not null,
  admin_token  uuid not null default gen_random_uuid(),
  is_open      boolean not null default true,
  hidden       text[] not null default '{}',
  created_at   timestamptz not null default now()
);

create table if not exists public.kq_submissions (
  id          uuid primary key default gen_random_uuid(),
  room_id     uuid not null references public.kq_rooms(id) on delete cascade,
  client_id   uuid not null,
  name        text not null,
  arch        text,
  norms       text[] not null,
  promise     text,
  xp          int,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (room_id, client_id)          -- satu peserta = satu suara (kirim ulang menimpa)
);
create index if not exists kq_submissions_room_idx on public.kq_submissions(room_id);

alter table public.kq_rooms enable row level security;
alter table public.kq_submissions enable row level security;
revoke all on public.kq_rooms, public.kq_submissions from anon, authenticated;

-- Normalisasi agar "Hadir Tepat Waktu" dan "hadir  tepat waktu" dihitung sama.
create or replace function public.kq_norm(t text) returns text
language sql immutable as $$
  select lower(regexp_replace(trim(coalesce(t,'')), '\s+', ' ', 'g'));
$$;

create or replace function public.kq_clean(t text, maxlen int) returns text
language sql immutable as $$
  select left(regexp_replace(trim(coalesce(t,'')), '\s+', ' ', 'g'), maxlen);
$$;

create or replace function public.kq_room(p_code text) returns public.kq_rooms
language sql stable security definer set search_path = public as $$
  select * from public.kq_rooms where code = upper(trim(coalesce(p_code,'')));
$$;

-- ---------- untuk fasilitator ----------
create or replace function public.kq_create_room(p_title text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_code text; r public.kq_rooms;
begin
  if char_length(trim(coalesce(p_title,''))) < 3 then raise exception 'Nama kelas minimal 3 karakter'; end if;
  loop
    v_code := (select string_agg(substr('ABCDEFGHJKMNPQRSTUVWXYZ23456789', 1 + floor(random()*31)::int, 1), '') from generate_series(1,5));
    exit when not exists (select 1 from public.kq_rooms where code = v_code);
  end loop;
  insert into public.kq_rooms(code, title) values (v_code, public.kq_clean(p_title, 80)) returning * into r;
  return jsonb_build_object('code', r.code, 'token', r.admin_token, 'title', r.title);
end $$;

create or replace function public.kq_admin(p_code text, p_token uuid, p_action text, p_arg text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare r public.kq_rooms;
begin
  r := public.kq_room(p_code);
  if r.id is null then raise exception 'Kode kelas tidak ditemukan'; end if;
  if r.admin_token is distinct from p_token then raise exception 'Token admin salah'; end if;
  if p_action = 'open' then update public.kq_rooms set is_open = true where id = r.id;
  elsif p_action = 'close' then update public.kq_rooms set is_open = false where id = r.id;
  elsif p_action = 'hide' then
    update public.kq_rooms set hidden = array(select distinct unnest(hidden || public.kq_norm(p_arg))) where id = r.id;
  elsif p_action = 'unhide_all' then update public.kq_rooms set hidden = '{}' where id = r.id;
  elsif p_action = 'reset' then delete from public.kq_submissions where room_id = r.id; update public.kq_rooms set hidden = '{}' where id = r.id;
  elsif p_action = 'check' then null;
  else raise exception 'Aksi tidak dikenal';
  end if;
  return jsonb_build_object('ok', true);
end $$;

-- ---------- untuk peserta ----------
create or replace function public.kq_room_info(p_code text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare r public.kq_rooms;
begin
  r := public.kq_room(p_code);
  if r.id is null then raise exception 'Kode kelas tidak ditemukan. Periksa kode dari fasilitator.'; end if;
  return jsonb_build_object('code', r.code, 'title', r.title, 'is_open', r.is_open);
end $$;

create or replace function public.kq_submit(p_code text, p_client uuid, p_name text, p_arch text, p_norms text[], p_promise text, p_xp int)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.kq_rooms; v_norms text[]; n int;
begin
  r := public.kq_room(p_code);
  if r.id is null then raise exception 'Kode kelas tidak ditemukan'; end if;
  if not r.is_open then raise exception 'Pengisian sudah ditutup fasilitator'; end if;
  if p_client is null then raise exception 'Identitas perangkat kosong'; end if;
  select array_agg(x) into v_norms from (
    select distinct on (public.kq_norm(x)) public.kq_clean(x, 40) as x
    from unnest(coalesce(p_norms,'{}')) x where char_length(trim(x)) > 0) z;
  n := coalesce(array_length(v_norms,1),0);
  if n < 1 or n > 3 then raise exception 'Pilih 1 sampai 3 norma'; end if;
  if (select count(*) from public.kq_submissions where room_id = r.id) >= 500
     and not exists (select 1 from public.kq_submissions where room_id = r.id and client_id = p_client) then
    raise exception 'Kelas sudah penuh (500 peserta)';
  end if;
  insert into public.kq_submissions(room_id, client_id, name, arch, norms, promise, xp)
  values (r.id, p_client, coalesce(nullif(public.kq_clean(p_name,24),''),'Peserta'),
          case when p_arch in ('penjelajah','perekat','perancang','penggerak') then p_arch end,
          v_norms, nullif(public.kq_clean(p_promise,120),''), least(greatest(coalesce(p_xp,0),0),5000))
  on conflict (room_id, client_id) do update set name = excluded.name, arch = excluded.arch, norms = excluded.norms,
    promise = excluded.promise, xp = excluded.xp, updated_at = now();
  return jsonb_build_object('ok', true, 'total', (select count(*) from public.kq_submissions where room_id = r.id));
end $$;

-- ---------- untuk papan (dibaca layar fasilitator) ----------
create or replace function public.kq_results(p_code text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare r public.kq_rooms;
begin
  r := public.kq_room(p_code);
  if r.id is null then raise exception 'Kode kelas tidak ditemukan'; end if;
  return jsonb_build_object(
    'code', r.code, 'title', r.title, 'is_open', r.is_open, 'hidden', to_jsonb(r.hidden),
    'total', (select count(*) from public.kq_submissions where room_id = r.id),
    'norms', coalesce((select jsonb_agg(jsonb_build_object('key', k, 'text', t, 'count', c) order by c desc, t)
       from (select public.kq_norm(x) k, mode() within group (order by x) t, count(*) c
             from public.kq_submissions s, unnest(s.norms) x where s.room_id = r.id
             group by public.kq_norm(x)) g where not (k = any(r.hidden))), '[]'::jsonb),
    'arch', coalesce((select jsonb_object_agg(arch, c) from (select arch, count(*) c from public.kq_submissions
       where room_id = r.id and arch is not null group by arch) a), '{}'::jsonb),
    'promises', coalesce((select jsonb_agg(p order by u desc) from (select promise p, updated_at u from public.kq_submissions
       where room_id = r.id and promise is not null order by updated_at desc limit 60) q), '[]'::jsonb),
    'updated_at', (select max(updated_at) from public.kq_submissions where room_id = r.id)
  );
end $$;

-- ---------- hak akses ----------
revoke execute on function public.kq_room(text), public.kq_norm(text), public.kq_clean(text,int) from public, anon, authenticated;
revoke execute on function public.kq_create_room(text), public.kq_admin(text,uuid,text,text), public.kq_room_info(text),
  public.kq_submit(text,uuid,text,text,text[],text,int), public.kq_results(text) from public;
grant execute on function public.kq_create_room(text), public.kq_admin(text,uuid,text,text), public.kq_room_info(text),
  public.kq_submit(text,uuid,text,text,text[],text,int), public.kq_results(text) to anon, authenticated;
-- fungsi internal tetap bisa dipakai oleh fungsi security definer di atas (pemiliknya postgres)
grant execute on function public.kq_norm(text), public.kq_clean(text,int) to anon, authenticated;
