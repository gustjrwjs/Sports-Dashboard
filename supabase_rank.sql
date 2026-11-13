-- SPORTS LIVE! 모두 함께 승부 예측 랭킹 (주간 적중왕)
-- Supabase → SQL Editor 에 전체 붙여넣고 Run (supabase_setup.sql 을 먼저 실행한 프로젝트에서 한 번만)
-- · 예측은 경기 시작 전까지만 인정: 서버가 ESPN에서 실제 시작 시간을 받아, 그 뒤에 바꾼 예측은 무효 처리
-- · 채점도 서버가 직접 ESPN 결과를 받아서 함 (사용자가 결과를 조작할 수 없음) — 10분마다 자동
-- · 사용자 비밀값은 해시로만 저장, 표는 직접 읽기·쓰기 불가(함수로만)

create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron;

create table if not exists public.preds (
  id          bigint generated always as identity primary key,
  owner_hash  text not null,
  nickname    text not null check (char_length(nickname) between 2 and 12),
  sport       text not null check (sport in ('soccer', 'basketball', 'baseball')),
  slug        text not null check (slug ~ '^[a-z0-9._]{2,40}$'),
  event_id    text not null check (event_id ~ '^[0-9]{3,20}$'),
  pick        text not null check (pick in ('home', 'draw', 'away')),
  ko_claim    timestamptz not null,           -- 앱이 알려준 시작 시간(채점 시점 잡기용)
  kickoff     timestamptz,                    -- ESPN 실제 시작 시간(채점 때 채움)
  result      text,
  status      text not null default 'open' check (status in ('open', 'hit', 'miss', 'void')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (owner_hash, event_id)
);
create index if not exists preds_open on public.preds (ko_claim) where status = 'open';
create index if not exists preds_kickoff on public.preds (kickoff);
alter table public.preds enable row level security;
revoke all on public.preds from anon, authenticated;

create table if not exists public.pred_jobs (
  event_id text primary key,
  req_id   bigint,
  tries    int not null default 0,
  tried_at timestamptz
);
alter table public.pred_jobs enable row level security;
revoke all on public.pred_jobs from anon, authenticated;

-- 예측 저장/변경/취소 (p_pick = null 이면 취소)
create or replace function public.pred_put(p_secret text, p_nick text, p_sport text, p_slug text, p_event text, p_pick text, p_kickoff timestamptz)
returns boolean language plpgsql security definer set search_path = public, extensions as $$
declare h text;
begin
  if char_length(coalesce(p_secret, '')) < 16 then raise exception '잘못된 요청입니다'; end if;
  if sl_reserved(p_nick) then raise exception '사용할 수 없는 닉네임입니다'; end if;
  if p_kickoff is null or p_kickoff <= now() then raise exception '경기가 이미 시작됐습니다'; end if;
  if p_kickoff > now() + interval '21 days' then raise exception '3주 안의 경기만 예측할 수 있습니다'; end if;
  h := sl_hash(p_secret);
  if (select count(*) from preds where owner_hash = h and updated_at > now() - interval '1 minute') > 40 then
    raise exception '잠시 후 다시 시도해 주세요';
  end if;
  if p_pick is null then
    delete from preds where owner_hash = h and event_id = p_event and status = 'open';
    return true;
  end if;
  insert into preds (owner_hash, nickname, sport, slug, event_id, pick, ko_claim)
  values (h, btrim(p_nick), p_sport, p_slug, p_event, p_pick, p_kickoff)
  on conflict (owner_hash, event_id) do update
    set pick = excluded.pick, nickname = excluded.nickname, ko_claim = excluded.ko_claim, updated_at = now()
    where preds.status = 'open';
  return true;
end $$;

-- 주간 순위 (적중 수 → 적중률 → 예측 수). p_secret 을 주면 내 줄 표시
create or replace function public.pred_rank(p_from timestamptz, p_to timestamptz, p_secret text default null)
returns table (rank bigint, nickname text, hits int, total int, pct int, is_me boolean)
language sql security definer set search_path = public, extensions as $$
  with s as (
    select owner_hash, (array_agg(nickname order by updated_at desc))[1] as nickname,
           count(*) filter (where status = 'hit')::int as hits, count(*)::int as total
    from preds
    where status in ('hit', 'miss') and kickoff >= p_from and kickoff < p_to
    group by owner_hash
  ), r as (
    select row_number() over (order by hits desc, hits::numeric / total desc, total desc, nickname) as rank,
           nickname, hits, total, round(100.0 * hits / total)::int as pct,
           (p_secret is not null and owner_hash = sl_hash(p_secret)) as is_me
    from s
  )
  select * from r where rank <= 20 or is_me order by rank
$$;

-- 채점 1단계: 시작 후 100분 지난 경기의 결과를 ESPN에 요청 (pg_net, 비동기)
create or replace function public.pred_fetch() returns int
language plpgsql security definer set search_path = public, extensions as $$
declare e record; n int := 0; rid bigint;
begin
  for e in
    select distinct on (p.event_id) p.event_id, p.sport, p.slug
    from preds p left join pred_jobs j on j.event_id = p.event_id
    where p.status = 'open' and p.ko_claim < now() - interval '100 minutes'
      and (j.event_id is null or (j.req_id is null and (j.tried_at is null or j.tried_at < now() - interval '20 minutes')))
    limit 40
  loop
    rid := net.http_get('https://site.api.espn.com/apis/site/v2/sports/' || e.sport || '/' || e.slug || '/summary?event=' || e.event_id);
    insert into pred_jobs (event_id, req_id, tries, tried_at) values (e.event_id, rid, 1, now())
    on conflict (event_id) do update set req_id = rid, tries = pred_jobs.tries + 1, tried_at = now();
    n := n + 1;
  end loop;
  return n;
end $$;

-- 채점 2단계: 받아 온 결과로 적중/실패/무효 기록
create or replace function public.pred_collect() returns int
language plpgsql security definer set search_path = public, extensions as $$
declare j record; r record; c jsonb; hm jsonb; aw jsonb; ko timestamptz; res text; hs numeric; as_ numeric; n int := 0;
begin
  for j in select * from pred_jobs where req_id is not null loop
    select * into r from net._http_response where id = j.req_id;
    if not found then
      if j.tried_at < now() - interval '30 minutes' then update pred_jobs set req_id = null where event_id = j.event_id; end if;
      continue;
    end if;
    c := null;
    begin
      if r.status_code = 200 then c := (r.content::jsonb) -> 'header' -> 'competitions' -> 0; end if;
    exception when others then c := null;
    end;
    if c is null or coalesce((c -> 'status' -> 'type' ->> 'completed')::boolean, false) = false then
      -- 아직 안 끝났거나 실패: 나중에 다시 (8번 넘게 실패하거나 시작 2일 지나도 안 끝나면 무효)
      update pred_jobs set req_id = null where event_id = j.event_id;
      if j.tries >= 8 or (c is not null and (c ->> 'date')::timestamptz < now() - interval '2 days')
         or (c is not null and (c -> 'status' -> 'type' ->> 'state') = 'post') then
        update preds set status = 'void' where event_id = j.event_id and status = 'open';
        delete from pred_jobs where event_id = j.event_id;
      end if;
      continue;
    end if;
    select x into hm from jsonb_array_elements(c -> 'competitors') x where x ->> 'homeAway' = 'home';
    select x into aw from jsonb_array_elements(c -> 'competitors') x where x ->> 'homeAway' = 'away';
    ko := (c ->> 'date')::timestamptz;
    hs := nullif(hm ->> 'score', '')::numeric; as_ := nullif(aw ->> 'score', '')::numeric;
    res := case when hs > as_ then 'home' when hs < as_ then 'away'
                when (hm ->> 'winner')::boolean is true and not exists (select 1 from preds where event_id = j.event_id and sport = 'soccer') then 'home'
                when (aw ->> 'winner')::boolean is true and not exists (select 1 from preds where event_id = j.event_id and sport = 'soccer') then 'away'
                else 'draw' end;
    update preds set kickoff = ko, result = res,
      status = case when updated_at >= ko then 'void' when pick = res then 'hit' else 'miss' end
    where event_id = j.event_id and status = 'open';
    delete from pred_jobs where event_id = j.event_id;
    n := n + 1;
  end loop;
  return n;
end $$;

revoke all on function public.pred_fetch() from public, anon, authenticated;
revoke all on function public.pred_collect() from public, anon, authenticated;
grant execute on function public.pred_put(text, text, text, text, text, text, timestamptz) to anon, authenticated;
grant execute on function public.pred_rank(timestamptz, timestamptz, text) to anon, authenticated;

-- 10분마다 자동 채점 (같은 이름이 있으면 먼저 지우고 다시 등록)
select cron.unschedule(jobid) from cron.job where jobname = 'sl-pred-grade';
select cron.schedule('sl-pred-grade', '*/10 * * * *', $$select public.pred_collect(); select public.pred_fetch();$$);

notify pgrst, 'reload schema';
