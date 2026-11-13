-- =====================================================================
-- SPORTS LIVE! 기기 연동(폰 ↔ PC) 데이터베이스 설정
--
-- 사용법: Supabase 대시보드 → SQL Editor → New query → 이 파일 내용을 전부 붙여넣기 → Run
-- 여러 번 실행해도 됩니다. (게시판용 supabase_setup.sql 과 따로 실행)
--
-- 구조
--   user_sync : 연동 코드(해시)별 My 경기·묶음·예측 기록·응원팀 (JSON 한 덩어리)
--   가입 없이 '연동 코드'(16자리)가 비밀번호 역할. 서버에는 코드 원문이 아니라 해시만 저장.
--   테이블 직접 읽기·쓰기는 막고(Row Level Security), 아래 두 함수로만 읽고 씀.
-- =====================================================================

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.user_sync (
  id         text primary key,                      -- sha256('sl-sync:' || 연동 코드)
  data       jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.user_sync enable row level security;
revoke all on public.user_sync from anon, authenticated;

-- 읽기: 코드가 맞으면 저장된 내용 반환 (없으면 null)
create or replace function public.sync_get(p_code text)
returns jsonb language sql security definer set search_path = public, extensions as $$
  select jsonb_build_object('data', data, 'updated_at', updated_at)
  from public.user_sync
  where length(coalesce(p_code, '')) >= 16
    and id = encode(extensions.digest('sl-sync:' || p_code, 'sha256'), 'hex')
$$;

-- 쓰기: 코드 자리에 통째로 저장 (최대 약 200KB)
create or replace function public.sync_put(p_code text, p_data jsonb)
returns timestamptz language plpgsql security definer set search_path = public, extensions as $$
declare t timestamptz;
begin
  if length(coalesce(p_code, '')) < 16 then raise exception '연동 코드가 올바르지 않습니다'; end if;
  if pg_column_size(p_data) > 200000 then raise exception '저장할 내용이 너무 큽니다'; end if;
  insert into public.user_sync (id, data, updated_at)
  values (encode(extensions.digest('sl-sync:' || p_code, 'sha256'), 'hex'), p_data, now())
  on conflict (id) do update set data = excluded.data, updated_at = now()
  returning updated_at into t;
  return t;
end $$;

revoke all on function public.sync_get(text) from public;
revoke all on function public.sync_put(text, jsonb) from public;
grant execute on function public.sync_get(text)          to anon, authenticated;
grant execute on function public.sync_put(text, jsonb)   to anon, authenticated;
