-- Multi-bar setup. Run once in the Supabase SQL editor.
-- Existing menu data is assigned to the current Praga Quart site.

create table public.bars (
  id text primary key,
  created_at timestamptz not null default now(),
  name text not null,
  slug text not null unique,
  type_label text not null default 'BAR',
  intro_eyebrow text not null default 'SABOR · AMIGOS · BUENAS CERVEZAS',
  intro_note text,
  footer_text text,
  footer_note text not null default 'P.V.P. IVA incluido',
  active boolean not null default true
);

insert into public.bars (id, name, slug, type_label, intro_note, footer_text)
values ('praga-quart', 'PRAGA QUART', 'praga-quart', 'BAR · CERVECERÍA', 'Cocina abierta hasta las 22:30', 'Disfruta de Praga Quart');

alter table public.categories add column bar_id text;
alter table public.subcategories add column bar_id text;
alter table public.products add column bar_id text;
alter table public.product_formats add column bar_id text;

update public.categories set bar_id = 'praga-quart';
update public.subcategories set bar_id = 'praga-quart';
update public.products set bar_id = 'praga-quart';
update public.product_formats set bar_id = 'praga-quart';

alter table public.categories alter column bar_id set not null;
alter table public.subcategories alter column bar_id set not null;
alter table public.products alter column bar_id set not null;
alter table public.product_formats alter column bar_id set not null;

alter table public.categories
  add constraint categories_bar_id_fkey foreign key (bar_id) references public.bars(id),
  add constraint categories_bar_id_id_key unique (bar_id, id);

alter table public.subcategories
  drop constraint subcategories_category_id_fkey,
  add constraint subcategories_bar_id_fkey foreign key (bar_id) references public.bars(id),
  add constraint subcategories_category_same_bar_fkey foreign key (bar_id, category_id) references public.categories(bar_id, id),
  add constraint subcategories_bar_id_id_key unique (bar_id, id);

alter table public.products
  drop constraint products_subcategory_id_fkey,
  add constraint products_bar_id_fkey foreign key (bar_id) references public.bars(id),
  add constraint products_subcategory_same_bar_fkey foreign key (bar_id, subcategory_id) references public.subcategories(bar_id, id),
  add constraint products_bar_id_id_key unique (bar_id, id);

alter table public.product_formats
  drop constraint product_formats_product_id_fkey,
  add constraint product_formats_bar_id_fkey foreign key (bar_id) references public.bars(id),
  add constraint product_formats_product_same_bar_fkey foreign key (bar_id, product_id) references public.products(bar_id, id);

create index categories_bar_sort_idx on public.categories(bar_id, sort_order);
create index subcategories_bar_sort_idx on public.subcategories(bar_id, sort_order);
create index products_bar_sort_idx on public.products(bar_id, sort_order);
create index product_formats_bar_sort_idx on public.product_formats(bar_id, sort_order);

-- Public menu reads; manage these tables from a trusted admin workflow.
alter table public.bars enable row level security;
alter table public.categories enable row level security;
alter table public.subcategories enable row level security;
alter table public.products enable row level security;
alter table public.product_formats enable row level security;

create policy "Public can read active bars" on public.bars for select using (active);
create policy "Public can read categories" on public.categories for select using (true);
create policy "Public can read subcategories" on public.subcategories for select using (true);
create policy "Public can read active products" on public.products for select using (active);
create policy "Public can read product formats" on public.product_formats for select using (true);
