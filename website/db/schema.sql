-- Admin dashboard schema. Safe to run repeatedly: every statement is
-- idempotent, so `npm run db:install` can be re-run after an edit.

-- School enquiries submitted through the "Register your school" form.
create table if not exists school_enquiries (
  id bigserial primary key,
  school_name text not null,
  school_location text not null,
  contact_name text not null,
  email text not null,
  phone text,
  learner_count text,
  programme_interest text,
  message text,
  status text not null default 'new',
  created_at timestamptz not null default now()
);

create index if not exists school_enquiries_created_at_idx
  on school_enquiries (created_at desc);

-- Team members shown on the homepage and /team.
create table if not exists team_members (
  id bigserial primary key,
  name text not null,
  role text not null,
  focus text,
  image text,
  bio text,
  position integer not null default 0,
  published boolean not null default true,
  created_at timestamptz not null default now()
);

-- News stories. The newest published post fills the homepage news block.
create table if not exists news_posts (
  id bigserial primary key,
  title text not null,
  excerpt text,
  image text,
  body text,
  published boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists news_posts_published_idx
  on news_posts (published, created_at desc);

-- LMS courses: the catalogue of learning pathways an admin maintains.
create table if not exists lms_courses (
  id bigserial primary key,
  title text not null,
  level text,
  summary text,
  topics text,
  duration text,
  link text,
  position integer not null default 0,
  published boolean not null default true,
  created_at timestamptz not null default now()
);

-- PWA apps the organisation publishes or recommends.
create table if not exists pwa_apps (
  id bigserial primary key,
  name text not null,
  category text,
  description text,
  url text,
  icon text,
  position integer not null default 0,
  published boolean not null default true,
  created_at timestamptz not null default now()
);

-- Learners: everyone who signed up for a course, and how far they have got.
create table if not exists learners (
  id bigserial primary key,
  full_name text not null,
  email text not null,
  phone text,
  school text,
  programme text not null default 'Python for Beginners',
  stage text not null default 'signed_up',
  progress integer not null default 0,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists learners_stage_idx on learners (stage, created_at desc);
create index if not exists learners_email_idx on learners (email);

-- LMS platform accounts. These tables belong to the learner app
-- (academy-skillshare.vercel.app/app) and are created here so a fresh database
-- has them; on the live database they already exist and these are no-ops.
-- Sign-in accounts live in neon_auth."user", which Neon Auth manages.
create table if not exists app_users (
  user_id text primary key,
  email text not null,
  display_name text,
  role text not null default 'LEARNER' check (role in ('ADMIN', 'PARENT', 'LEARNER')),
  status text not null default 'active' check (status in ('active', 'suspended', 'deactivated')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_seen_at timestamptz
);

create table if not exists parent_learner (
  id text primary key default (gen_random_uuid())::text,
  parent_user_id text not null references app_users (user_id) on delete cascade,
  learner_user_id text not null references app_users (user_id) on delete cascade,
  relationship text not null default 'guardian',
  status text not null default 'active' check (status in ('pending', 'active', 'suspended', 'revoked')),
  verified_at timestamptz,
  linked_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists leaderboard_entries (
  id text primary key,
  display_name text not null,
  avatar_data text,
  steps_completed integer not null default 0,
  practices_completed integer not null default 0,
  score_total integer not null default 0,
  source text not null default 'web',
  updated_at timestamptz not null default now()
);

create table if not exists audit_log (
  id bigserial primary key,
  actor_user_id text,
  action text not null,
  entity_type text not null,
  entity_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists audit_log_created_at_idx on audit_log (created_at desc);
