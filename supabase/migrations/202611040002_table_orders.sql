-- Run after 202611040001_multi_bar.sql.

create table public.bar_tables (
  id uuid primary key default gen_random_uuid(),
  bar_id text not null references public.bars(id),
  table_number text not null,
  public_code text not null unique,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint bar_tables_bar_id_id_key unique (bar_id, id),
  constraint bar_tables_bar_number_key unique (bar_id, table_number)
);

create index bar_tables_bar_active_idx on public.bar_tables(bar_id, active);

alter table public.product_formats
  add constraint product_formats_bar_id_id_key unique (bar_id, id);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  bar_id text not null references public.bars(id),
  table_id uuid not null,
  table_number_snapshot text not null,
  status text not null default 'received',
  total numeric(10, 2) not null default 0 check (total >= 0),
  created_at timestamptz not null default now(),
  constraint orders_bar_id_id_key unique (bar_id, id),
  constraint orders_table_same_bar_fkey foreign key (bar_id, table_id) references public.bar_tables(bar_id, id),
  constraint orders_status_check check (status in ('received', 'preparing', 'ready', 'served', 'cancelled'))
);

create index orders_bar_created_idx on public.orders(bar_id, created_at desc);
create index orders_table_created_idx on public.orders(table_id, created_at desc);

create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  bar_id text not null,
  order_id uuid not null,
  product_id text not null,
  format_id uuid not null,
  product_name_snapshot text not null,
  format_name_snapshot text not null,
  unit_price numeric(10, 2) not null check (unit_price >= 0),
  quantity integer not null check (quantity > 0),
  line_total numeric(10, 2) not null check (line_total >= 0),
  created_at timestamptz not null default now(),
  constraint order_items_order_same_bar_fkey foreign key (bar_id, order_id) references public.orders(bar_id, id) on delete cascade,
  constraint order_items_product_same_bar_fkey foreign key (bar_id, product_id) references public.products(bar_id, id),
  constraint order_items_format_same_bar_fkey foreign key (bar_id, format_id) references public.product_formats(bar_id, id)
);

create index order_items_order_idx on public.order_items(order_id);
create index order_items_bar_created_idx on public.order_items(bar_id, created_at desc);

alter table public.bar_tables enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

revoke all on public.bar_tables from anon, authenticated;
grant select on public.bar_tables to anon, authenticated;
create policy "Public can resolve active QR tables" on public.bar_tables
  for select to anon, authenticated using (active);

revoke all on public.orders from anon, authenticated;
revoke all on public.order_items from anon, authenticated;

create or replace function public.create_table_order(
  p_bar_slug text,
  p_table_code text,
  p_items jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bar_id text;
  v_table_id uuid;
  v_table_number text;
  v_order_id uuid;
  v_format_id uuid;
  v_quantity integer;
  v_product_id text;
  v_product_name text;
  v_format_name text;
  v_unit_price numeric(10, 2);
  v_total numeric(10, 2) := 0;
  v_line jsonb;
begin
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'El pedido debe incluir al menos un producto.' using errcode = '22023';
  end if;
  if jsonb_array_length(p_items) > 100 then
    raise exception 'El pedido contiene demasiadas líneas.' using errcode = '22023';
  end if;

  select b.id into v_bar_id
  from public.bars as b
  where b.slug = p_bar_slug and b.active = true;
  if v_bar_id is null then
    raise exception 'Bar no disponible.' using errcode = '22023';
  end if;

  select t.id, t.table_number into v_table_id, v_table_number
  from public.bar_tables as t
  where t.bar_id = v_bar_id and t.public_code = p_table_code and t.active = true;
  if v_table_id is null then
    raise exception 'Mesa no válida.' using errcode = '22023';
  end if;

  insert into public.orders (bar_id, table_id, table_number_snapshot)
  values (v_bar_id, v_table_id, v_table_number)
  returning id into v_order_id;

  for v_line in select value from jsonb_array_elements(p_items)
  loop
    v_format_id := (v_line->>'formatId')::uuid;
    v_quantity := (v_line->>'quantity')::integer;
    if v_quantity is null or v_quantity < 1 or v_quantity > 99 then
      raise exception 'Cantidad no válida.' using errcode = '22023';
    end if;

    select f.product_id, p.name, f.name, f.price
      into v_product_id, v_product_name, v_format_name, v_unit_price
    from public.product_formats as f
    join public.products as p on p.id = f.product_id and p.bar_id = f.bar_id
    where f.id = v_format_id and f.bar_id = v_bar_id and p.active = true;
    if not found then
      raise exception 'Producto o formato no disponible.' using errcode = '22023';
    end if;

    insert into public.order_items (
      bar_id, order_id, product_id, format_id, product_name_snapshot,
      format_name_snapshot, unit_price, quantity, line_total
    ) values (
      v_bar_id, v_order_id, v_product_id, v_format_id, v_product_name,
      v_format_name, v_unit_price, v_quantity, v_unit_price * v_quantity
    );

    v_total := v_total + v_unit_price * v_quantity;
  end loop;

  update public.orders set total = v_total where id = v_order_id;
  return jsonb_build_object('order_id', v_order_id, 'total', v_total);
end;
$$;

revoke all on function public.create_table_order(text, text, jsonb) from public;
grant execute on function public.create_table_order(text, text, jsonb) to anon, authenticated;
