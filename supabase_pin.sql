-- SPORTS LIVE! 게시판 "📌 공지 고정" 추가 (supabase_setup.sql을 이미 실행한 프로젝트에 한 번만 실행)
-- 고정/해제는 운영자 비밀번호가 맞을 때만 서버에서 허용됩니다. 비밀번호는 이 파일에 없습니다.
alter table public.posts add column if not exists pinned boolean not null default false;
create index if not exists posts_cat_pin_time on public.posts (category, pinned desc, created_at desc);
grant select (pinned) on public.posts to anon, authenticated;

create or replace function public.admin_pin_post(p_id bigint, p_pin boolean, p_pass text)
returns boolean language plpgsql security definer set search_path = public, extensions as $$
begin
  if not sl_is_admin(p_pass) then raise exception '운영자 비밀번호가 틀렸습니다'; end if;
  update posts set pinned = coalesce(p_pin, false) where id = p_id;
  return found;
end $$;
revoke all on function public.admin_pin_post(bigint, boolean, text) from public;
grant execute on function public.admin_pin_post(bigint, boolean, text) to anon, authenticated;
notify pgrst, 'reload schema';
