-- Ranking global · English Exam Kahoot  (pega TODO esto en Supabase > SQL Editor > Run)
create table if not exists public.players(
  id uuid primary key,
  name text not null check (char_length(name) between 2 and 20),
  created_at timestamptz not null default now());
create table if not exists public.scores(
  game_id uuid primary key,                       -- id único de partida (evita duplicados)
  player_id uuid not null references public.players(id) on delete cascade,
  name text not null check (char_length(name) between 2 and 20),
  score int not null check (score between 0 and 25000),
  correct int not null check (correct between 0 and 25),
  total int not null check (total = 25),
  pct int not null check (pct between 0 and 100),
  created_at timestamptz not null default now(),
  check (score between correct*600 and correct*1000));  -- cada acierto vale 600 a 1000
create index if not exists scores_player_idx on public.scores(player_id, score desc, created_at);
create index if not exists scores_rank_idx on public.scores(score desc, created_at);

-- RLS activado y SIN políticas: nadie puede leer ni escribir las tablas directamente.
alter table public.players enable row level security;
alter table public.scores enable row level security;
revoke all on public.players, public.scores from anon, authenticated;

-- Única vía de escritura: validada, idempotente y con límite de frecuencia.
create or replace function public.submit_score(p_player uuid, p_name text, p_game uuid, p_score int, p_correct int, p_total int)
returns text language plpgsql security definer set search_path = public as $$
declare n text := btrim(regexp_replace(regexp_replace(coalesce(p_name,''), '[[:cntrl:]]', '', 'g'), '\s+', ' ', 'g'));
begin
  if char_length(n) < 2 or char_length(n) > 20 or n ~ '[<>&"]' then raise exception 'bad_name'; end if;
  if p_player is null or p_game is null or p_total is distinct from 25 or p_correct is null or p_score is null
     or p_correct < 0 or p_correct > 25 or p_score < p_correct*600 or p_score > p_correct*1000 then raise exception 'bad_score'; end if;
  if exists (select 1 from scores s where s.game_id = p_game) then return 'ok'; end if;   -- reenvío: ya guardado
  if exists (select 1 from scores s where s.player_id = p_player and s.created_at > now() - interval '40 seconds')
     then raise exception 'too_fast'; end if;
  insert into players(id, name) values (p_player, n) on conflict (id) do update set name = excluded.name;
  insert into scores(game_id, player_id, name, score, correct, total, pct)
    values (p_game, p_player, n, p_score, p_correct, 25, round(p_correct*100.0/25)) on conflict (game_id) do nothing;
  return 'ok';
end $$;

-- Mejores jugadores: récord de cada player_id. Desempate: puntos, luego quién lo logró antes.
create or replace function public.get_ranking(p_limit int default 20, p_offset int default 0)
returns table(pos bigint, name text, score int, correct int, pct int, played timestamptz, total bigint)
language sql stable security definer set search_path = public as $$
  with b as (select distinct on (s.player_id) s.player_id, s.score, s.correct, s.pct, s.created_at
             from scores s order by s.player_id, s.score desc, s.created_at asc),
  r as (select row_number() over (order by b.score desc, b.created_at asc, b.player_id) as pos, p.name, b.score, b.correct, b.pct,
               b.created_at as played, count(*) over () as total
        from b join players p on p.id = b.player_id)
  select r.pos, r.name, r.score, r.correct, r.pct, r.played, r.total from r order by r.pos
  limit least(greatest(p_limit,1),50) offset greatest(p_offset,0) $$;

create or replace function public.get_my_rank(p_player uuid)
returns table(pos bigint, score int)
language sql stable security definer set search_path = public as $$
  with b as (select distinct on (s.player_id) s.player_id, s.score, s.created_at
             from scores s order by s.player_id, s.score desc, s.created_at asc),
  r as (select b.player_id, b.score, row_number() over (order by b.score desc, b.created_at asc, b.player_id) as pos from b)
  select r.pos, r.score from r where r.player_id = p_player $$;

-- Historial de partidas (p_sort: 'date' o 'score').
create or replace function public.get_history(p_limit int default 20, p_offset int default 0, p_sort text default 'date')
returns table(name text, score int, correct int, pct int, played timestamptz, total bigint)
language sql stable security definer set search_path = public as $$
  select s.name, s.score, s.correct, s.pct, s.created_at, count(*) over () from scores s
  order by (case when p_sort = 'score' then s.score end) desc nulls last, s.created_at desc, s.game_id
  limit least(greatest(p_limit,1),50) offset greatest(p_offset,0) $$;

grant execute on function public.submit_score(uuid,text,uuid,int,int,int), public.get_ranking(int,int),
  public.get_my_rank(uuid), public.get_history(int,int,text) to anon, authenticated;
