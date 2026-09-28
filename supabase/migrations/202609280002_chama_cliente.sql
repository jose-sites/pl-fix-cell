alter table public.leads
  add column if not exists request_type text not null default 'service',
  add column if not exists quantity integer not null default 1,
  add column if not exists trade_in boolean not null default false,
  add column if not exists trade_in_brand text;

alter table public.leads drop constraint if exists leads_request_type_check;
alter table public.leads add constraint leads_request_type_check
  check (request_type in ('new_device', 'used_device', 'service'));

alter table public.leads drop constraint if exists leads_quantity_check;
alter table public.leads add constraint leads_quantity_check
  check (quantity between 1 and 99);

alter table public.leads drop constraint if exists leads_trade_in_check;
alter table public.leads add constraint leads_trade_in_check
  check (
    trade_in = false
    or (
      request_type = 'used_device'
      and lower(coalesce(trade_in_brand, '')) in ('iphone', 'apple')
    )
  );

create or replace function public.submit_store_lead(
  customer_name text,
  customer_phone text,
  desired_item text,
  request_details text,
  selected_request_type text,
  selected_quantity integer default 1,
  wants_trade_in boolean default false,
  selected_trade_in_brand text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_id uuid;
  clean_name text := trim(coalesce(customer_name, ''));
  clean_phone text := nullif(trim(coalesce(customer_phone, '')), '');
  clean_item text := trim(coalesce(desired_item, ''));
  clean_details text := trim(coalesce(request_details, ''));
  clean_brand text := nullif(trim(coalesce(selected_trade_in_brand, '')), '');
begin
  if length(clean_name) < 2 or length(clean_name) > 100 then
    raise exception 'Informe um nome válido.';
  end if;
  if clean_phone is not null and length(clean_phone) > 30 then
    raise exception 'Telefone inválido.';
  end if;
  if length(clean_item) < 2 or length(clean_item) > 200 then
    raise exception 'Informe o aparelho ou serviço desejado.';
  end if;
  if length(clean_details) > 1000 then
    raise exception 'Os detalhes devem ter até 1000 caracteres.';
  end if;
  if selected_request_type not in ('new_device', 'used_device', 'service') then
    raise exception 'Tipo de solicitação inválido.';
  end if;
  if selected_quantity is null or selected_quantity < 1 or selected_quantity > 99 then
    raise exception 'Quantidade inválida.';
  end if;
  if selected_request_type = 'service' then
    selected_quantity := 1;
  end if;
  if wants_trade_in and (
    selected_request_type <> 'used_device'
    or lower(coalesce(clean_brand, '')) not in ('iphone', 'apple')
  ) then
    raise exception 'Aceitamos apenas iPhones como entrada para a compra de Seminovos.';
  end if;

  insert into public.leads (
    name, phone, service, details, source, consent_contact, status,
    request_type, quantity, trade_in, trade_in_brand
  ) values (
    clean_name, clean_phone, clean_item, nullif(clean_details, ''),
    'products_page', clean_phone is not null, 'new',
    selected_request_type, selected_quantity, wants_trade_in,
    case when wants_trade_in then clean_brand else null end
  ) returning id into new_id;

  return new_id;
end;
$$;

revoke all on function public.submit_store_lead(text,text,text,text,text,integer,boolean,text) from public;
grant execute on function public.submit_store_lead(text,text,text,text,text,integer,boolean,text) to anon, authenticated;
