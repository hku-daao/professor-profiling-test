-- HKU professor mirror from HKU Scholars Hub (hub.hku.hk). Run in Supabase SQL editor or CLI.

create table if not exists public.professors (
    id uuid primary key default gen_random_uuid(),
    cris_rp_id text not null unique,
    name_en text,
    name_zh text,
    titles text[] not null default '{}',
    faculty text,
    department text,
    research_interests text,
    profile_url text,
    display_heading text,
    publications jsonb not null default '[]'::jsonb,
    external_relations jsonb not null default '[]'::jsonb,
    university_responsibilities jsonb not null default '[]'::jsonb,
    grants jsonb not null default '[]'::jsonb,
    synced_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists professors_name_en_idx on public.professors (name_en);
create index if not exists professors_faculty_idx on public.professors (faculty);
create index if not exists professors_department_idx on public.professors (department);

alter table public.professors enable row level security;

create policy "Allow public read professors"
    on public.professors for select
    to anon, authenticated
    using (true);

-- Writes use service_role from the Railway sync job (bypasses RLS).

comment on table public.professors is 'Synced from HKU Scholars Hub ResearcherPage (Staff); not an official HKU dataset.';
