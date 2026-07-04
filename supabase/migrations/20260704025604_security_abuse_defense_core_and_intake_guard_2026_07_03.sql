-- FilmComOS hardening (2026-07-03). Applied to prod via MCP; committed same-session.
-- Abuse-defense core + BEFORE INSERT guard on intake_submissions (its only
-- always-true public insert). Abuse tables are service-role only in this pilot.
create table if not exists public.abuse_events (
  id bigint generated always as identity primary key,
  occurred_at timestamptz not null default now(),
  identifier text not null, kind text not null, route text,
  severity int not null default 1, detail jsonb not null default '{}', user_agent text
);
create index if not exists abuse_events_ident_time on public.abuse_events(identifier, occurred_at desc);
create table if not exists public.ip_blocklist (
  identifier text primary key, reason text not null, kind text not null default 'auto',
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  expires_at timestamptz, created_by text
);
create index if not exists ip_blocklist_expires on public.ip_blocklist(expires_at);
create table if not exists public.rate_buckets (
  identifier text not null, route text not null, bucket_start timestamptz not null,
  hits int not null default 0, primary key (identifier, route, bucket_start)
);
create index if not exists rate_buckets_start on public.rate_buckets(bucket_start);

alter table public.abuse_events enable row level security;
alter table public.ip_blocklist enable row level security;
alter table public.rate_buckets enable row level security;
revoke all on public.abuse_events, public.ip_blocklist, public.rate_buckets from anon, authenticated;

create or replace function public.sec_client_ip()
returns text language sql stable security definer set search_path = public, pg_temp as $$
  select coalesce(
    nullif(btrim(split_part(current_setting('request.headers', true)::json->>'x-forwarded-for', ',', 1)), ''),
    current_setting('request.headers', true)::json->>'cf-connecting-ip',
    current_setting('request.headers', true)::json->>'x-real-ip', 'unknown');
$$;
create or replace function public.sec_is_blocked(p_identifier text)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists(select 1 from public.ip_blocklist where identifier=p_identifier and (expires_at is null or expires_at>now()));
$$;
create or replace function public.sec_check_rate(p_identifier text, p_route text, p_max int, p_window_secs int)
returns boolean language plpgsql security definer set search_path = public, pg_temp as $$
declare v_bucket timestamptz := date_trunc('minute', now()); v_total int;
begin
  if p_identifier='unknown' then return true; end if;
  insert into public.rate_buckets(identifier, route, bucket_start, hits)
  values (p_identifier, p_route, v_bucket, 1)
  on conflict (identifier, route, bucket_start) do update set hits = public.rate_buckets.hits + 1;
  select coalesce(sum(hits),0) into v_total from public.rate_buckets
   where identifier=p_identifier and route=p_route and bucket_start > now() - make_interval(secs => p_window_secs);
  delete from public.rate_buckets where bucket_start < now() - interval '2 hours';
  return v_total <= p_max;
end; $$;
create or replace function public.sec_log_abuse(
  p_identifier text, p_kind text, p_route text default null,
  p_severity int default 1, p_detail jsonb default '{}', p_user_agent text default null)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare v_score int;
begin
  insert into public.abuse_events(identifier, kind, route, severity, detail, user_agent)
  values (p_identifier, p_kind, p_route, p_severity, coalesce(p_detail,'{}'), p_user_agent);
  if p_identifier is null or p_identifier='unknown' then return; end if;
  select coalesce(sum(severity),0) into v_score from public.abuse_events
   where identifier=p_identifier and occurred_at > now() - interval '15 minutes';
  if v_score >= 10 then
    insert into public.ip_blocklist(identifier, reason, kind, expires_at)
    values (p_identifier, format('auto: abuse score %s in 15m', v_score), 'auto', now() + interval '24 hours')
    on conflict (identifier) do update set reason=excluded.reason,
      expires_at=greatest(coalesce(public.ip_blocklist.expires_at, now()), excluded.expires_at), updated_at=now();
  end if;
end; $$;
create or replace function public.sec_guard_public_insert()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare v_role text := coalesce(current_setting('request.jwt.claims', true)::json->>'role','anon');
        v_ip text; v_ua text;
begin
  if v_role='service_role' then return NEW; end if;
  v_ip := public.sec_client_ip();
  v_ua := current_setting('request.headers', true)::json->>'user-agent';
  if public.sec_is_blocked(v_ip) then
    perform public.sec_log_abuse(v_ip,'blocked_insert_attempt',TG_TABLE_NAME,3,jsonb_build_object('table',TG_TABLE_NAME),v_ua);
    raise exception 'Request denied.' using errcode='42501';
  end if;
  if not public.sec_check_rate(v_ip,'insert:'||TG_TABLE_NAME,8,60) then
    perform public.sec_log_abuse(v_ip,'rate_limit_exceeded',TG_TABLE_NAME,4,jsonb_build_object('table',TG_TABLE_NAME,'limit','8/60s'),v_ua);
    raise exception 'Too many requests. Please slow down and try again shortly.' using errcode='53400';
  end if;
  return NEW;
end; $$;

drop trigger if exists trg_sec_guard_intake_submissions on public.intake_submissions;
create trigger trg_sec_guard_intake_submissions before insert on public.intake_submissions
  for each row execute function public.sec_guard_public_insert();

revoke execute on function public.sec_client_ip(), public.sec_check_rate(text,text,int,int),
  public.sec_log_abuse(text,text,text,int,jsonb,text) from public, anon, authenticated;
grant execute on function public.sec_is_blocked(text) to anon, authenticated, service_role;
grant execute on function public.sec_client_ip() to service_role;
grant execute on function public.sec_check_rate(text,text,int,int) to service_role;
grant execute on function public.sec_log_abuse(text,text,text,int,jsonb,text) to service_role;

comment on table public.abuse_events is 'Security: abuse log (2026-07-03). Guards intake_submissions; attach sec_guard_public_insert() to new public-writable tables.';
