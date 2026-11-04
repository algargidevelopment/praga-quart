alter table public.products
  add column if not exists detailed_description text;

comment on column public.products.detailed_description is
  'Descripción ampliada que se muestra en la ficha del producto.';
