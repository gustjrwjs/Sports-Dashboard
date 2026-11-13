-- SPORTS LIVE! 회원가입 · 로그인 (아이디 + 비밀번호)
-- Supabase → SQL Editor 에 전체 붙여넣고 Run (여러 번 실행해도 됩니다)
-- · 이메일 없이 아이디·비밀번호로 가입 (메일 발송 설정이 필요 없음) → 비밀번호를 잊으면 찾을 수 없음(화면에 안내)
-- · 비밀번호는 bcrypt 해시로만 저장, 로그인 토큰도 해시로만 저장 (원문은 서버에 없음)
-- · 표는 직접 읽기·쓰기 불가, 아래 함수로만
-- · 비밀번호 10번 틀리면 15분 잠금, 가입은 10분에 전체 30명까지(도배 방지)

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.accounts (
  uid          text primary key check (uid ~ '^[a-z0-9_]{4,16}$'),
  pw_hash      text not null,
  nick         text not null check (char_length(nick) between 2 and 12),
  data         jsonb not null default '{}'::jsonb,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  fails        int not null default 0,
  locked_until timestamptz
);
create table if not exists public.acc_tokens (
  token_hash text primary key,
  uid        text not null references public.accounts (uid) on delete cascade,
  expires_at timestamptz not null
);
create index if not exists acc_tokens_uid on public.acc_tokens (uid);
alter table public.accounts enable row level security;
alter table public.acc_tokens enable row level security;
revoke all on public.accounts from anon, authenticated;
revoke all on public.acc_tokens from anon, authenticated;

-- 토큰 발급 (180일)
create or replace function public.acc_issue(p_uid text) returns text
language plpgsql security definer set search_path = public, extensions as $$
declare t text := encode(extensions.gen_random_bytes(24), 'hex');
begin
  delete from acc_tokens where uid = p_uid and expires_at < now();
  insert into acc_tokens (token_hash, uid, expires_at) values (encode(extensions.digest(t, 'sha256'), 'hex'), p_uid, now() + interval '180 days');
  return t;
end $$;

create or replace function public.acc_uid(p_token text) returns text
language sql stable security definer set search_path = public, extensions as $$
  select uid from acc_tokens where length(coalesce(p_token, '')) = 48
    and token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex') and expires_at > now()
$$;

-- 가입 → 토큰
create or replace function public.acc_signup(p_uid text, p_pw text, p_nick text) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare u text := lower(btrim(coalesce(p_uid, '')));
begin
  if u !~ '^[a-z0-9_]{4,16}$' then raise exception '아이디는 영어 소문자·숫자·_ 4~16자로 정해 주세요'; end if;
  if char_length(coalesce(p_pw, '')) < 6 or char_length(p_pw) > 72 then raise exception '비밀번호는 6자 이상으로 정해 주세요'; end if;
  if char_length(btrim(coalesce(p_nick, ''))) not between 2 and 12 then raise exception '닉네임은 2~12자로 정해 주세요'; end if;
  if sl_reserved(p_nick) or sl_reserved(u) then raise exception '사용할 수 없는 아이디·닉네임입니다'; end if;
  if (select count(*) from accounts where created_at > now() - interval '10 minutes') >= 30 then raise exception '지금 가입이 많아요. 잠시 후 다시 시도해 주세요'; end if;
  if exists (select 1 from accounts where uid = u) then raise exception '이미 있는 아이디입니다'; end if;
  insert into accounts (uid, pw_hash, nick) values (u, extensions.crypt(p_pw, extensions.gen_salt('bf', 10)), btrim(p_nick));
  return jsonb_build_object('token', acc_issue(u), 'uid', u, 'nick', btrim(p_nick));
end $$;

-- 로그인 → 토큰
create or replace function public.acc_login(p_uid text, p_pw text) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare a accounts; u text := lower(btrim(coalesce(p_uid, '')));
begin
  -- 틀린 경우는 예외 대신 error 를 돌려줌 (예외를 내면 틀린 횟수 기록까지 취소되므로)
  select * into a from accounts where uid = u;
  if not found then perform extensions.crypt(coalesce(p_pw, ''), extensions.gen_salt('bf', 10)); return jsonb_build_object('error', '아이디 또는 비밀번호가 맞지 않습니다'); end if;
  if a.locked_until is not null and a.locked_until > now() then return jsonb_build_object('error', '비밀번호를 여러 번 틀려 잠시 잠겼습니다. 15분 뒤 다시 시도해 주세요'); end if;
  if a.pw_hash <> extensions.crypt(coalesce(p_pw, ''), a.pw_hash) then
    update accounts set fails = fails + 1, locked_until = case when fails + 1 >= 10 then now() + interval '15 minutes' else null end where uid = u;
    return jsonb_build_object('error', '아이디 또는 비밀번호가 맞지 않습니다');
  end if;
  update accounts set fails = 0, locked_until = null where uid = u;
  return jsonb_build_object('token', acc_issue(u), 'uid', u, 'nick', a.nick);
end $$;

-- 내 데이터 읽기 / 쓰기
create or replace function public.acc_get(p_token text) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare u text := acc_uid(p_token); a accounts;
begin
  if u is null then raise exception '로그인이 만료됐습니다. 다시 로그인해 주세요'; end if;
  select * into a from accounts where uid = u;
  return jsonb_build_object('uid', a.uid, 'nick', a.nick, 'data', a.data, 'updated_at', a.updated_at);
end $$;

create or replace function public.acc_put(p_token text, p_data jsonb) returns timestamptz
language plpgsql security definer set search_path = public, extensions as $$
declare u text := acc_uid(p_token); t timestamptz;
begin
  if u is null then raise exception '로그인이 만료됐습니다. 다시 로그인해 주세요'; end if;
  if pg_column_size(p_data) > 300000 then raise exception '저장할 내용이 너무 큽니다'; end if;
  update accounts set data = coalesce(p_data, '{}'::jsonb), updated_at = now() where uid = u returning updated_at into t;
  return t;
end $$;

create or replace function public.acc_logout(p_token text) returns boolean
language sql security definer set search_path = public, extensions as $$
  delete from acc_tokens where token_hash = encode(extensions.digest(coalesce(p_token, ''), 'sha256'), 'hex') returning true
$$;

-- 닉네임 · 비밀번호 바꾸기, 탈퇴
create or replace function public.acc_nick(p_token text, p_nick text) returns boolean
language plpgsql security definer set search_path = public, extensions as $$
declare u text := acc_uid(p_token);
begin
  if u is null then raise exception '로그인이 만료됐습니다. 다시 로그인해 주세요'; end if;
  if char_length(btrim(coalesce(p_nick, ''))) not between 2 and 12 or sl_reserved(p_nick) then raise exception '사용할 수 없는 닉네임입니다'; end if;
  update accounts set nick = btrim(p_nick) where uid = u;
  return true;
end $$;

create or replace function public.acc_passwd(p_token text, p_old text, p_new text) returns boolean
language plpgsql security definer set search_path = public, extensions as $$
declare u text := acc_uid(p_token); a accounts;
begin
  if u is null then raise exception '로그인이 만료됐습니다. 다시 로그인해 주세요'; end if;
  if char_length(coalesce(p_new, '')) < 6 or char_length(p_new) > 72 then raise exception '새 비밀번호는 6자 이상으로 정해 주세요'; end if;
  select * into a from accounts where uid = u;
  if a.pw_hash <> extensions.crypt(coalesce(p_old, ''), a.pw_hash) then raise exception '지금 비밀번호가 맞지 않습니다'; end if;
  update accounts set pw_hash = extensions.crypt(p_new, extensions.gen_salt('bf', 10)) where uid = u;
  delete from acc_tokens where uid = u and token_hash <> encode(extensions.digest(p_token, 'sha256'), 'hex');  -- 다른 기기는 다시 로그인
  return true;
end $$;

create or replace function public.acc_delete(p_token text, p_pw text) returns boolean
language plpgsql security definer set search_path = public, extensions as $$
declare u text := acc_uid(p_token); a accounts;
begin
  if u is null then raise exception '로그인이 만료됐습니다. 다시 로그인해 주세요'; end if;
  select * into a from accounts where uid = u;
  if a.pw_hash <> extensions.crypt(coalesce(p_pw, ''), a.pw_hash) then raise exception '비밀번호가 맞지 않습니다'; end if;
  delete from accounts where uid = u;
  return true;
end $$;

revoke all on function public.acc_issue(text) from public, anon, authenticated;
revoke all on function public.acc_uid(text) from public, anon, authenticated;
grant execute on function public.acc_signup(text, text, text) to anon, authenticated;
grant execute on function public.acc_login(text, text) to anon, authenticated;
grant execute on function public.acc_get(text) to anon, authenticated;
grant execute on function public.acc_put(text, jsonb) to anon, authenticated;
grant execute on function public.acc_logout(text) to anon, authenticated;
grant execute on function public.acc_nick(text, text) to anon, authenticated;
grant execute on function public.acc_passwd(text, text, text) to anon, authenticated;
grant execute on function public.acc_delete(text, text) to anon, authenticated;

notify pgrst, 'reload schema';
