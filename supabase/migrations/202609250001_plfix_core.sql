create extension if not exists pgcrypto;

create table if not exists public.admin_users (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  created_at timestamptz not null default now()
);

insert into public.admin_users (email)
values ('plfix@concerto.com')
on conflict (email) do nothing;

create or replace function public.is_plfix_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.admin_users
    where lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;

create table if not exists public.service_prices (
  id uuid primary key default gen_random_uuid(),
  brand text not null,
  model text not null,
  service text not null,
  price numeric(10,2),
  price_type text not null default 'fixed' check (price_type in ('fixed','from','quote')),
  warranty_text text,
  turnaround_text text,
  notes text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists service_prices_lookup_idx on public.service_prices (lower(brand), lower(model), lower(service)) where active;

create table if not exists public.used_iphones (
  id uuid primary key default gen_random_uuid(),
  model text not null,
  storage text,
  battery_health integer check (battery_health between 0 and 100),
  condition text,
  color text,
  price numeric(10,2),
  featured boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.faq_entries (
  id uuid primary key default gen_random_uuid(),
  question text not null,
  answer text not null,
  keywords text[] not null default '{}',
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.chat_sessions (
  id uuid primary key default gen_random_uuid(),
  visitor_id text not null unique,
  visitor_name text,
  visitor_phone text,
  consent_contact boolean not null default false,
  started_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.chat_sessions(id) on delete cascade,
  role text not null check (role in ('user','assistant')),
  content text not null,
  intent text,
  matched_price_id uuid references public.service_prices(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists chat_messages_session_idx on public.chat_messages (session_id, created_at);

create table if not exists public.leads (
  id uuid primary key default gen_random_uuid(),
  session_id uuid references public.chat_sessions(id) on delete set null,
  name text,
  phone text,
  service text,
  brand text,
  model text,
  details text,
  source text not null default 'site',
  consent_contact boolean not null default false,
  status text not null default 'new' check (status in ('new','contacted','quoted','won','lost')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.analytics_events (
  id bigint generated always as identity primary key,
  visitor_id text not null,
  event_name text not null,
  page text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists analytics_events_name_date_idx on public.analytics_events (event_name, created_at desc);

create table if not exists public.business_settings (
  id integer primary key default 1 check (id = 1),
  business_name text not null default 'PL Fix Cell',
  whatsapp text not null default '5527996133131',
  address text not null default 'Av. Principal - Rio Marinho, Cariacica - ES, 29141-752',
  ai_enabled boolean not null default true,
  ai_model text not null default 'openai/gpt-oss-20b',
  ai_system_note text,
  updated_at timestamptz not null default now()
);

insert into public.business_settings (id) values (1) on conflict (id) do nothing;

insert into public.faq_entries (question, answer, keywords, sort_order)
values
  ('Quanto tempo demora o conserto?', 'O prazo depende do modelo, do defeito e da disponibilidade da peça. Envie os dados do aparelho para uma estimativa.', array['prazo','tempo','demora'], 1),
  ('Qual a garantia?', 'A garantia depende do serviço e da peça utilizada. As condições são informadas no orçamento antes do reparo.', array['garantia'], 2),
  ('Onde fica a loja?', 'A PL Fix Cell fica na Av. Principal, Rio Marinho, Cariacica - ES, CEP 29141-752.', array['endereço','localização','onde'], 3)
on conflict do nothing;

create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;

drop trigger if exists service_prices_touch on public.service_prices;
create trigger service_prices_touch before update on public.service_prices for each row execute function public.touch_updated_at();
drop trigger if exists used_iphones_touch on public.used_iphones;
create trigger used_iphones_touch before update on public.used_iphones for each row execute function public.touch_updated_at();
drop trigger if exists faq_entries_touch on public.faq_entries;
create trigger faq_entries_touch before update on public.faq_entries for each row execute function public.touch_updated_at();
drop trigger if exists leads_touch on public.leads;
create trigger leads_touch before update on public.leads for each row execute function public.touch_updated_at();

alter table public.admin_users enable row level security;
alter table public.service_prices enable row level security;
alter table public.used_iphones enable row level security;
alter table public.faq_entries enable row level security;
alter table public.chat_sessions enable row level security;
alter table public.chat_messages enable row level security;
alter table public.leads enable row level security;
alter table public.analytics_events enable row level security;
alter table public.business_settings enable row level security;

create policy "admins manage admin users" on public.admin_users for all to authenticated using (public.is_plfix_admin()) with check (public.is_plfix_admin());
create policy "public reads active prices" on public.service_prices for select to anon, authenticated using (active);
create policy "admins manage prices" on public.service_prices for all to authenticated using (public.is_plfix_admin()) with check (public.is_plfix_admin());
create policy "public reads active inventory" on public.used_iphones for select to anon, authenticated using (active);
create policy "admins manage inventory" on public.used_iphones for all to authenticated using (public.is_plfix_admin()) with check (public.is_plfix_admin());
create policy "public reads active faq" on public.faq_entries for select to anon, authenticated using (active);
create policy "admins manage faq" on public.faq_entries for all to authenticated using (public.is_plfix_admin()) with check (public.is_plfix_admin());
create policy "admins read sessions" on public.chat_sessions for select to authenticated using (public.is_plfix_admin());
create policy "admins read messages" on public.chat_messages for select to authenticated using (public.is_plfix_admin());
create policy "admins manage leads" on public.leads for all to authenticated using (public.is_plfix_admin()) with check (public.is_plfix_admin());
create policy "admins read analytics" on public.analytics_events for select to authenticated using (public.is_plfix_admin());
create policy "public reads settings" on public.business_settings for select to anon, authenticated using (true);
create policy "admins manage settings" on public.business_settings for all to authenticated using (public.is_plfix_admin()) with check (public.is_plfix_admin());

alter publication supabase_realtime add table public.service_prices;
alter publication supabase_realtime add table public.used_iphones;
alter publication supabase_realtime add table public.chat_messages;
alter publication supabase_realtime add table public.leads;
alter publication supabase_realtime add table public.analytics_events;
