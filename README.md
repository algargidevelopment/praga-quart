# Praga Menu

Web de carta con Vue, TypeScript, Vite y Supabase. El mismo proyecto puede servir la carta de varios bares: cada despliegue selecciona el bar mediante su `slug`.

## Configuración

Define estas variables en `.env.local` (no subas este archivo al repositorio):

```env
VITE_SUPABASE_URL=https://tu-proyecto.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=tu-clave-publicable
VITE_BAR_SLUG=praga-quart
```

Para otro sitio, configura `VITE_BAR_SLUG` con el slug de ese bar y despliega la web con las mismas credenciales de Supabase.

## Base de datos multi-bar

Ejecuta una sola vez `supabase/migrations/202611040001_multi_bar.sql` en el SQL Editor de Supabase. La migración crea `bars`, asocia los registros existentes al bar `praga-quart` y agrega `bar_id` a categorías, subcategorías, productos y formatos. Las claves foráneas compuestas impiden asociar elementos de bares distintos.

Después ejecuta `supabase/migrations/202611040002_table_orders.sql`. Crea mesas, pedidos y líneas de pedido, y una función que valida la mesa, vuelve a leer los precios y guarda el pedido completo en una transacción.

Para añadir un bar, crea un registro en `bars` con un `id` único y un `slug` único. Después inserta las categorías, subcategorías, productos y formatos con ese mismo `bar_id`. Los textos de marca y presentación se configuran en `bars`.

La aplicación consulta la carta por `bar_id` obtenido del slug y muestra solo los datos de ese bar. Las políticas de la migración permiten lecturas públicas de las cartas y no conceden permisos de escritura pública.

## Mesas y códigos QR

Crea una fila en `bar_tables` por mesa. El `public_code` es el token aleatorio que identifica el QR:

```sql
insert into public.bar_tables (bar_id, table_number, public_code)
values ('praga-quart', '1', gen_random_uuid()::text)
returning public_code;
```

Usa el valor `public_code` para generar este enlace en el QR de esa mesa. Para GitHub Pages, el proyecto se publica bajo `/praga-quart/`:

```text
https://algargidevelopment.github.io/praga-quart/?mesa=PUBLIC_CODE
```

La web obtiene el bar de `VITE_BAR_SLUG` y valida el token de mesa. Al confirmar, invoca `create_table_order`; el navegador solo envía IDs de formato y cantidades. La función calcula los precios desde la carta y guarda `orders` y `order_items` juntos. El código del QR es público, así que desactiva una mesa poniendo `active = false` si su QR se pierde o cambia.

## Publicar en GitHub Pages

El workflow `.github/workflows/deploy.yml` compila y publica `dist` cada vez que se actualiza `main`. En el repositorio de GitHub, configura **Settings → Pages → Build and deployment → Source: GitHub Actions**. Después, añade `VITE_SUPABASE_URL` y `VITE_SUPABASE_PUBLISHABLE_KEY` en **Settings → Secrets and variables → Actions → Variables**. La clave publishable se inserta en el JavaScript público del sitio; nunca pongas una `service_role` o secret key en el frontend.

La URL resultante es `https://algargidevelopment.github.io/praga-quart/`. Una vez publicado, los QR usarán esa URL más `?mesa=PUBLIC_CODE`.

## Desarrollo

```sh
npm install
npm run dev
```

Para compilar:

```sh
npm run build
```
