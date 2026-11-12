-- =====================================================================
-- SPORTS LIVE! 커뮤니티(자랑하기·문의 게시판) 데이터베이스 설정
--
-- 사용법: Supabase 대시보드 → SQL Editor → New query → 이 파일 내용을 전부 붙여넣기
--         → 맨 아래 '관리자 비밀번호' 부분을 꼭 바꾼 뒤 → Run
-- 여러 번 실행해도 됩니다(이미 있는 건 건너뛰거나 덮어씀).
--
-- 구조
--   posts     : 글 (category = 'brag' 자랑하기, 'qna' 문의)
--   comments  : 댓글 (운영자 답변은 is_admin = true)
--   방문자는 가입 없이 닉네임만으로 글을 씀. 글·댓글 쓰기/삭제/추천은 모두 아래 함수(RPC)로만 가능하고
--   테이블에 직접 쓰기는 막혀 있음(Row Level Security).
--   본인 글 삭제: 글 쓸 때 기기에 저장된 비밀값(secret)의 해시로 확인.
-- =====================================================================

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------- 테이블
create table if not exists public.posts (
  id            bigint generated always as identity primary key,
  created_at    timestamptz not null default now(),
  category      text not null check (category in ('brag', 'qna')),
  nickname      text not null check (char_length(nickname) between 2 and 12),
  title         text not null check (char_length(title) between 1 and 60),
  body          text not null check (char_length(body) between 1 and 2000),
  image_url     text check (image_url is null or image_url like 'https://%/storage/v1/object/public/brag/%'),
  likes         int  not null default 0,
  comment_count int  not null default 0,
  owner_hash    text not null,
  hidden        boolean not null default false
);
create index if not exists posts_cat_time on public.posts (category, created_at desc);

create table if not exists public.comments (
  id          bigint generated always as identity primary key,
  post_id     bigint not null references public.posts (id) on delete cascade,
  created_at  timestamptz not null default now(),
  nickname    text not null check (char_length(nickname) between 2 and 12),
  body        text not null check (char_length(body) between 1 and 500),
  is_admin    boolean not null default false,
  owner_hash  text not null
);
create index if not exists comments_post_time on public.comments (post_id, created_at);

-- 관리자 비밀번호(해시) 보관. 정책이 없어서 API로는 아무도 못 읽음.
create table if not exists public.admin_config (
  id        int primary key default 1 check (id = 1),
  pass_hash text not null
);

-- ---------------------------------------------------------------- 보안 규칙 (읽기만 허용)
alter table public.posts        enable row level security;
alter table public.comments     enable row level security;
alter table public.admin_config enable row level security;

drop policy if exists "read visible posts" on public.posts;
create policy "read visible posts" on public.posts for select to anon, authenticated using (not hidden);

drop policy if exists "read comments" on public.comments;
create policy "read comments" on public.comments for select to anon, authenticated
  using (exists (select 1 from public.posts p where p.id = post_id and not p.hidden));

-- 비밀값 해시는 읽기에서 숨김
revoke select on public.posts from anon, authenticated;
grant select (id, created_at, category, nickname, title, body, image_url, likes, comment_count) on public.posts to anon, authenticated;
revoke select on public.comments from anon, authenticated;
grant select (id, post_id, created_at, nickname, body, is_admin) on public.comments to anon, authenticated;
revoke all on public.admin_config from anon, authenticated;

-- ---------------------------------------------------------------- 함수 (쓰기는 전부 여기로)
create or replace function public.sl_hash(p text) returns text
language sql immutable set search_path = public, extensions as $$
  select encode(extensions.digest(p, 'sha256'), 'hex')
$$;

-- 운영자 사칭 닉네임 막기
create or replace function public.sl_reserved(n text) returns boolean
language sql immutable as $$
  select lower(regexp_replace(coalesce(n, ''), '\s', '', 'g')) ~ '(운영자|관리자|운영진|admin|sportslive|스포츠라이브)'
$$;

create or replace function public.create_post(p_category text, p_nickname text, p_title text, p_body text, p_image_url text, p_secret text)
returns bigint language plpgsql security definer set search_path = public, extensions as $$
declare h text; new_id bigint;
begin
  if char_length(coalesce(p_secret, '')) < 16 then raise exception '잘못된 요청입니다'; end if;
  if sl_reserved(p_nickname) then raise exception '사용할 수 없는 닉네임입니다'; end if;
  h := sl_hash(p_secret);
  if exists (select 1 from posts where owner_hash = h and created_at > now() - interval '30 seconds') then
    raise exception '글은 30초에 한 번만 올릴 수 있습니다';
  end if;
  if (select count(*) from posts where created_at > now() - interval '10 minutes') > 60 then
    raise exception '지금 글이 너무 많이 올라오고 있어요. 잠시 후 다시 시도해 주세요';
  end if;
  insert into posts (category, nickname, title, body, image_url, owner_hash)
  values (p_category, btrim(p_nickname), btrim(p_title), btrim(p_body), nullif(p_image_url, ''), h)
  returning id into new_id;
  return new_id;
end $$;

create or replace function public.add_comment(p_post bigint, p_nickname text, p_body text, p_secret text)
returns bigint language plpgsql security definer set search_path = public, extensions as $$
declare h text; new_id bigint;
begin
  if char_length(coalesce(p_secret, '')) < 16 then raise exception '잘못된 요청입니다'; end if;
  if sl_reserved(p_nickname) then raise exception '사용할 수 없는 닉네임입니다'; end if;
  if not exists (select 1 from posts where id = p_post and not hidden) then raise exception '글이 없습니다'; end if;
  h := sl_hash(p_secret);
  if exists (select 1 from comments where owner_hash = h and created_at > now() - interval '10 seconds') then
    raise exception '댓글은 10초에 한 번만 쓸 수 있습니다';
  end if;
  insert into comments (post_id, nickname, body, owner_hash) values (p_post, btrim(p_nickname), btrim(p_body), h)
  returning id into new_id;
  update posts set comment_count = comment_count + 1 where id = p_post;
  return new_id;
end $$;

create or replace function public.delete_post(p_id bigint, p_secret text)
returns boolean language plpgsql security definer set search_path = public, extensions as $$
begin
  delete from posts where id = p_id and owner_hash = sl_hash(p_secret);
  return found;
end $$;

create or replace function public.delete_comment(p_id bigint, p_secret text)
returns boolean language plpgsql security definer set search_path = public, extensions as $$
declare pid bigint;
begin
  delete from comments where id = p_id and owner_hash = sl_hash(p_secret) returning post_id into pid;
  if pid is null then return false; end if;
  update posts set comment_count = greatest(comment_count - 1, 0) where id = pid;
  return true;
end $$;

create or replace function public.like_post(p_id bigint)
returns int language sql security definer set search_path = public as $$
  update posts set likes = likes + 1 where id = p_id and not hidden returning likes
$$;

-- ---------------------------------------------------------------- 운영자 기능 (비밀번호 필요)
create or replace function public.sl_is_admin(p_pass text) returns boolean
language sql security definer set search_path = public, extensions as $$
  -- 예시 비밀번호를 안 바꾸고 실행했으면 운영자 기능이 꺼진 상태로 둠
  select coalesce(p_pass, '') <> '여기에-관리자-비밀번호' and char_length(coalesce(p_pass, '')) >= 8
     and exists (select 1 from admin_config where pass_hash = extensions.crypt(p_pass, pass_hash))
$$;

create or replace function public.admin_check(p_pass text) returns boolean
language sql security definer set search_path = public as $$ select sl_is_admin(p_pass) $$;

create or replace function public.admin_comment(p_post bigint, p_body text, p_pass text)
returns bigint language plpgsql security definer set search_path = public, extensions as $$
declare new_id bigint;
begin
  if not sl_is_admin(p_pass) then raise exception '운영자 비밀번호가 틀렸습니다'; end if;
  insert into comments (post_id, nickname, body, is_admin, owner_hash)
  values (p_post, '운영자', btrim(p_body), true, 'admin') returning id into new_id;
  update posts set comment_count = comment_count + 1 where id = p_post;
  return new_id;
end $$;

create or replace function public.admin_delete_post(p_id bigint, p_pass text)
returns boolean language plpgsql security definer set search_path = public, extensions as $$
begin
  if not sl_is_admin(p_pass) then raise exception '운영자 비밀번호가 틀렸습니다'; end if;
  delete from posts where id = p_id;
  return found;
end $$;

create or replace function public.admin_delete_comment(p_id bigint, p_pass text)
returns boolean language plpgsql security definer set search_path = public, extensions as $$
declare pid bigint;
begin
  if not sl_is_admin(p_pass) then raise exception '운영자 비밀번호가 틀렸습니다'; end if;
  delete from comments where id = p_id returning post_id into pid;
  if pid is not null then update posts set comment_count = greatest(comment_count - 1, 0) where id = pid; end if;
  return pid is not null;
end $$;

revoke all on function public.sl_is_admin(text) from public, anon, authenticated;
grant execute on function public.create_post(text, text, text, text, text, text) to anon, authenticated;
grant execute on function public.add_comment(bigint, text, text, text)           to anon, authenticated;
grant execute on function public.delete_post(bigint, text)                       to anon, authenticated;
grant execute on function public.delete_comment(bigint, text)                    to anon, authenticated;
grant execute on function public.like_post(bigint)                               to anon, authenticated;
grant execute on function public.admin_check(text)                               to anon, authenticated;
grant execute on function public.admin_comment(bigint, text, text)               to anon, authenticated;
grant execute on function public.admin_delete_post(bigint, text)                 to anon, authenticated;
grant execute on function public.admin_delete_comment(bigint, text)              to anon, authenticated;

-- ---------------------------------------------------------------- 사진 저장소 (자랑하기 첨부 이미지)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('brag', 'brag', true, 2097152, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = true, file_size_limit = 2097152,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

drop policy if exists "brag upload" on storage.objects;
create policy "brag upload" on storage.objects for insert to anon, authenticated
  with check (bucket_id = 'brag' and (storage.foldername(name))[1] = 'u');

-- ---------------------------------------------------------------- 관리자 비밀번호 설정
-- ↓↓↓ '여기에-관리자-비밀번호' 를 회원님만 아는 긴 비밀번호로 바꾼 뒤 실행하세요 (이 파일을 저장소에 올릴 때는 바꾸지 마세요)
insert into public.admin_config (id, pass_hash)
values (1, extensions.crypt('여기에-관리자-비밀번호', extensions.gen_salt('bf')))
on conflict (id) do update set pass_hash = excluded.pass_hash;
