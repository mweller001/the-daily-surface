-- =============================================================
-- My Intentional Life — v0.1 Supabase setup
-- Paste this whole block into:  Supabase → SQL Editor → New query → Run
-- =============================================================
--
-- Design note (why it looks like this):
-- The data layer is deliberately SCHEMA-LIGHT. Instead of rigid columns for
-- every task property (which would force a formal migration every time the
-- app's shape changes — fighting fast iteration), each record stores its
-- shape in a single flexible JSON column called `data`. The app reads it
-- tolerantly: missing fields get defaults, old records keep working. This
-- lets the data layer iterate almost as fast as the presentation layer,
-- which is the cost we chose to bear in the cheapest possible way.
--
-- There is one table per "kind" of thing for now (items), distinguished by a
-- `kind` field inside the JSON ('task', 'appointment', 'project', etc.), so
-- the whole suite can grow without new tables until the structure stabilizes.

-- ---- the single flexible store ----
create table if not exists items (
  id          uuid primary key default gen_random_uuid(),
  kind        text not null,                       -- 'task' | 'appointment' | 'project' | 'goal' | 'setting' ...
  data        jsonb not null default '{}'::jsonb,  -- the flexible shape lives here
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- keep updated_at fresh on every change
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists items_updated_at on items;
create trigger items_updated_at
  before update on items
  for each row execute function set_updated_at();

-- a helpful index for fetching by kind
create index if not exists items_kind_idx on items (kind);

-- =============================================================
-- Row Level Security (RLS)
-- =============================================================
-- RLS governs what the PUBLIC (publishable) key is allowed to do.
-- For v0.1 this is a SINGLE-USER, non-sensitive utility, and the app has no
-- login yet, so we allow the public key full read/write on `items`.
--
-- IMPORTANT (stated plainly, since you'll rightly want to know the posture):
-- with these rules, anyone who had your app URL AND your publishable key
-- could read/write this table. For v0.1 task data that's an acceptable,
-- low-stakes posture — but it is NOT the long-term posture. When the
-- structure stabilizes we add real auth (a login) and tighten these rules so
-- only your authenticated account can touch your data. This is the
-- "defer the expensive until the structure settles" decision, applied to
-- security: correct-enough now, properly locked later. Flagging it so it's a
-- known, chosen tradeoff rather than an accident.

alter table items enable row level security;

drop policy if exists items_public_all on items;
create policy items_public_all
  on items
  for all
  using (true)
  with check (true);
