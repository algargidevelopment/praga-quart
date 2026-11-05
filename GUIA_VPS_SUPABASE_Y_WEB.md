# Guía para reconstruir la VPS, Supabase y las webs de los bares

Esta guía recoge el montaje que estamos usando: Ubuntu 24.04, usuario `deploy`, Supabase autohospedado con Docker, Caddy como proxy HTTPS, y una web Vue independiente para cada subdominio de `jogargar.es`.

## 0. Antes de empezar: datos y arquitectura

Necesitas:

- Un VPS Ubuntu 24.04 LTS. Para Supabase completo, toma como base al menos 2 vCPU, 4 GB RAM y 40 GB SSD (lo que tiene el servidor actual). Para producción real o varios bares con uso, conviene más memoria, disco y copias externas.
- Acceso al panel del proveedor para abrir el firewall de red.
- Acceso a Hostalia para administrar el DNS de `jogargar.es`.
- Una clave SSH Ed25519 en cada ordenador desde el que vayas a administrar.
- El código fuente de la web Vue en este ordenador.

La distribución final queda así:

| Uso | Dirección | Destino |
|---|---|---|
| Supabase API y Studio | `https://supabase.jogargar.es` | VPS, puerto 443 |
| Web de Praga Quart | `https://praga-quart.jogargar.es` | El mismo VPS, puerto 443 |
| Otros bares | `https://<slug>.jogargar.es` | El mismo VPS, puerto 443 |

Todos los subdominios pueden apuntar a la misma IP. Caddy elige qué servir según el nombre del dominio. La base de datos y la API no se exponen directamente a Internet; Caddy es la única entrada web pública.

**Sustituye** `<IP_NUEVA>` por la IP que te asigne el proveedor. En esta conversación el servidor actual es `27.0.172.109`, pero en una VPS nueva no debes reutilizarla sin comprobarla.

---

## 1. Crear la VPS y preparar DNS

1. Crea Ubuntu **24.04 LTS**, con la capacidad indicada arriba.
2. En el firewall del proveedor permite entrada TCP `22`, `80` y `443`. No abras `5432`, `6543` ni `8000`.
3. En Hostalia entra en `panel.hostalia.com` → gestión de DNS de `jogargar.es` → añadir registro.
4. Crea registros **A** para cada subdominio, todos con la IP de la VPS:

   | Nombre/host | Tipo | Valor |
   |---|---|---|
   | `supabase` | A | `<IP_NUEVA>` |
   | `praga-quart` | A | `<IP_NUEVA>` |
   | cada nuevo slug (por ejemplo `bar-nuevo`) | A | `<IP_NUEVA>` |

   Si el panel pide el nombre completo, usa `supabase.jogargar.es` y `praga-quart.jogargar.es`. No crees un registro para cada carpeta; el DNS solo lleva el dominio a la IP.
5. Espera la propagación y comprueba desde Windows:

   ```powershell
   Resolve-DnsName supabase.jogargar.es -Type A -Server 1.1.1.1
   Resolve-DnsName praga-quart.jogargar.es -Type A -Server 1.1.1.1
   ```

   Deben devolver `<IP_NUEVA>`. Si el DNS público no devuelve la IP, revisa que el registro se haya guardado en los servidores autoritativos de Hostalia y que no se haya escrito mal el host.

---

## 2. Primer acceso y cuenta administrativa segura

Conéctate inicialmente como `root` usando la contraseña temporal del proveedor:

```powershell
ssh root@<IP_NUEVA>
```

Actualiza Ubuntu e instala herramientas básicas:

```bash
apt update
apt full-upgrade -y
apt install -y sudo ufw unattended-upgrades curl ca-certificates gnupg git
```

Crea la cuenta de administración normal:

```bash
adduser deploy
usermod -aG sudo deploy
```

En Windows, crea una clave si aún no tienes una:

```powershell
ssh-keygen -t ed25519
```

Puedes aceptar la ruta sugerida. Una frase de paso protege la clave privada si el portátil se pierde. **Copia al servidor únicamente el contenido del archivo que termina en `.pub`**; nunca compartas ni copies la clave privada.

Como `root`, instala la clave pública del usuario `deploy` (reemplaza el texto de ejemplo por la línea completa del archivo `.pub`):

```bash
install -d -m 700 -o deploy -g deploy /home/deploy/.ssh
nano /home/deploy/.ssh/authorized_keys
chown deploy:deploy /home/deploy/.ssh/authorized_keys
chmod 600 /home/deploy/.ssh/authorized_keys
```

En `nano`, pega la línea pública completa, guarda con `Ctrl+O`, Enter, sal con `Ctrl+X`. Abre **otra ventana** de PowerShell y verifica el acceso antes de cerrar root:

```powershell
ssh deploy@<IP_NUEVA>
whoami
```

Debe mostrar `deploy`. Mantén la sesión root abierta hasta verificar tanto SSH como el firewall.

---

## 3. Endurecer SSH y activar UFW

Desde la sesión `deploy`, configura SSH para aceptar claves y rechazar contraseñas y acceso root:

```bash
sudo nano /etc/ssh/sshd_config.d/00-hardening.conf
```

Contenido:

```text
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
```

Comprueba la sintaxis y recarga el servicio:

```bash
sudo sshd -t
sudo systemctl reload ssh
sudo sshd -T | grep -E 'permitrootlogin|pubkeyauthentication|passwordauthentication|kbdinteractiveauthentication'
```

En UFW, permite SSH **antes de activarlo** para no perder el acceso:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw logging low
sudo ufw enable
sudo ufw status verbose
```

Desde otra ventana, abre una nueva sesión `ssh deploy@<IP_NUEVA>` y confirma que entra. Después puedes salir de la sesión root inicial. Para tareas administrativas usa `sudo`; `sudo -i` abre una shell root temporal y `exit` vuelve a `deploy`.

Activa actualizaciones automáticas de seguridad:

```bash
sudo dpkg-reconfigure -plow unattended-upgrades
```

Si al actualizar aparece que hace falta reiniciar, hazlo en un momento en que puedas reconectar:

```bash
sudo reboot
```

---

## 4. Instalar Supabase autohospedado con Docker

El instalador oficial prepara Docker/Compose y el directorio del proyecto. Ejecútalo como `deploy`, no como root:

```bash
mkdir -p ~/supabase-install
cd ~/supabase-install
curl -fsSL https://supabase.link/setup.sh -o setup.sh
less setup.sh
```

Revisa el script (`q` sale de `less`) y ejecútalo:

```bash
sh setup.sh
```

Sigue las preguntas del asistente. Usa los dominios reales:

- URL pública de Supabase: `https://supabase.jogargar.es`
- URL de la web para redirecciones de Auth: `https://praga-quart.jogargar.es/`
- El hostname del proxy, cuando lo solicite: `supabase.jogargar.es` (sin `https://` ni ruta).

El asistente crea `~/supabase-install/supabase-project`. Entra:

```bash
cd ~/supabase-install/supabase-project
```

### 4.1 Configurar secretos y URL públicas

Edita `.env`:

```bash
nano .env
```

Comprueba/ajusta estas variables, respetando los nombres presentes en la versión instalada:

```dotenv
SUPABASE_PUBLIC_URL=https://supabase.jogargar.es
API_EXTERNAL_URL=https://supabase.jogargar.es
SITE_URL=https://praga-quart.jogargar.es/
ADDITIONAL_REDIRECT_URLS=https://praga-quart.jogargar.es/**
PROXY_DOMAIN=supabase.jogargar.es
```

Si la versión que instalaste define `API_EXTERNAL_URL` con sufijo `/auth/v1`, conserva el formato que espera esa plantilla. Lo importante es no usar `localhost`, la URL temporal de Cloudflare ni HTTP en la URL pública. Añade los dominios de otros bares a las redirecciones de Auth cuando uses login desde ellos.

Guarda también los valores generados para `POSTGRES_PASSWORD`, `JWT_SECRET`, claves anon/publishable, `DASHBOARD_USERNAME` y `DASHBOARD_PASSWORD` en un gestor de contraseñas. No los pegues en la web, GitHub, capturas públicas ni chats. Las claves anon/publishable pueden ir en el cliente web; la `service_role`, `secret key`, contraseña Postgres y JWT secret **nunca**.

Protege el archivo:

```bash
chmod 600 .env
```

### 4.2 Activar Caddy y arrancar servicios

El instalador de esta instalación incluye un override de Caddy. Habilítalo y levanta los contenedores:

```bash
sh run.sh config add caddy
sh run.sh start
docker compose ps
```

Espera a que los servicios aparezcan como `healthy`. Caddy debe publicar `80` y `443`. La API gateway, Postgres y el pooler no deben quedar publicados en una IP pública. Verifica:

```bash
docker compose ps
```

El pooler, si se publica, debe estar ligado a `127.0.0.1`; el acceso web público pasa por Caddy. Revisa también el firewall del proveedor y UFW: solo `22`, `80`, `443` deben estar permitidos desde Internet.

Abre `https://supabase.jogargar.es`. El navegador pedirá autenticación HTTP Basic de Caddy: usa `DASHBOARD_USERNAME` y `DASHBOARD_PASSWORD` del `.env`. Este es un acceso adicional al Studio; después Studio puede tener su propio inicio de sesión. Si el navegador repite el cuadro, comprueba esas credenciales y que Caddy esté leyendo el `.env`; las credenciales Basic se quedan guardadas por el navegador hasta cerrar la ventana privada.

### 4.3 Direcciones del frontend

La aplicación Vue debe usar la URL pública real de la API:

```dotenv
VITE_SUPABASE_URL=https://supabase.jogargar.es
VITE_SUPABASE_PUBLISHABLE_KEY=<clave publishable/anon pública del .env del servidor>
VITE_BAR_SLUG=praga-quart
```

`localhost:8000` solo era correcto mientras el navegador se conectaba localmente al túnel. Con el dominio y Caddy funcionando, el frontend usa `https://supabase.jogargar.es`.

---

## 5. Crear las tablas e importar el menú

Hazlo en Studio (`https://supabase.jogargar.es`) → **SQL Editor** y **Table Editor**. En una instalación nueva, primero se crean las cuatro tablas base, luego se importan los CSV y después se aplican las migraciones del proyecto.

### 5.1 Crear el esquema base

Ejecuta una sola vez este SQL en el SQL Editor:

```sql
create table public.categories (
  id text primary key,
  created_at timestamptz not null default now(),
  name text not null,
  icon text not null,
  note text,
  sort_order integer not null default 0
);

create table public.subcategories (
  id text primary key,
  created_at timestamptz not null default now(),
  category_id text not null,
  name text not null,
  sort_order integer not null default 0,
  constraint subcategories_category_id_fkey foreign key (category_id) references public.categories(id)
);

create table public.products (
  id text primary key,
  created_at timestamptz not null default now(),
  subcategory_id text not null,
  name text not null,
  description text,
  image_path text,
  sort_order integer not null default 0,
  active boolean not null default true,
  constraint products_subcategory_id_fkey foreign key (subcategory_id) references public.subcategories(id)
);

create table public.product_formats (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  product_id text not null,
  name text not null,
  price numeric not null,
  sort_order integer not null default 0,
  constraint product_formats_product_id_fkey foreign key (product_id) references public.products(id)
);
```

No ejecutes este bloque por segunda vez sobre las mismas tablas. Si ya existen, revisa su estructura antes de continuar; no las borres para “empezar limpio” si hay datos que quieras conservar.

### 5.2 Importar CSV

En **Table Editor**, importa los CSV del proyecto (`supabase/import/`) en este orden, para respetar las claves foráneas:

1. `categories.csv` → `categories`
2. `subcategories.csv` → `subcategories`
3. `products.csv` → `products`
4. `product_formats.csv` → `product_formats`

Usa la opción de importar CSV en la tabla correspondiente; no pegues solo la fila de encabezados en el editor SQL. Comprueba que se reconoce la primera fila como encabezado y que los campos de precio y `active` quedan como número/booleano.

### 5.3 Aplicar las migraciones del proyecto

Desde el SQL Editor ejecuta los archivos **en este orden**:

1. `supabase/migrations/202611040001_multi_bar.sql`
2. `supabase/migrations/202611040002_table_orders.sql`
3. `supabase/migrations/202611040003_detailed_product_description.sql`

Cada migración se ejecuta una sola vez en una base nueva. La primera registra el bar `praga-quart`, asigna las filas importadas a ese bar y configura políticas de lectura pública del menú. La segunda crea mesas, pedidos y la función segura que registra pedidos QR. La tercera añade la descripción detallada de producto.

### 5.4 Storage de imágenes

En **Storage** crea un bucket llamado exactamente `productos`. Como las imágenes del menú se muestran mediante URL pública, márcalo como público para lectura. No crees una política de escritura anónima: subir/gestionar archivos debe hacerse desde Studio autenticado.

Dentro del bucket, crea/sube los archivos usando la ruta `products/`, por ejemplo:

```text
productos (bucket)
└── products/
    ├── beer-18-70.png
    └── ...
```

La columna `image_path` de los CSV debe coincidir con la ruta relativa del archivo, por ejemplo `products/beer-18-70.png`. Respeta mayúsculas, minúsculas y extensión. Comprueba una URL pública de una imagen en el navegador antes de dar por terminado el despliegue.

### 5.5 Crear la mesa 1 y su QR

Después de ejecutar las migraciones, en el SQL Editor:

```sql
insert into public.bar_tables (bar_id, table_number, public_code)
values ('praga-quart', '1', gen_random_uuid()::text)
returning id, table_number, public_code;
```

Guarda `public_code` y crea el QR con esta URL (reemplaza el marcador por el resultado):

```text
https://praga-quart.jogargar.es/?mesa=<PUBLIC_CODE>
```

Para otra mesa repite el `INSERT` con `table_number` distinto. No reutilices el código público entre mesas.

---

## 6. Configurar Caddy para servir las webs

En el servidor, el Caddyfile de esta instalación está dentro del volumen del proyecto. Comprueba la ubicación:

```bash
cd ~/supabase-install/supabase-project
find volumes/proxy/caddy -maxdepth 2 -type f
```

Crea un directorio para los archivos compilados de Praga Quart:

```bash
mkdir -p volumes/proxy/caddy/sites/praga-quart/dist
```

Edita `volumes/proxy/caddy/Caddyfile` y conserva los bloques existentes que publican Supabase/Studio. Añade al final:

```caddyfile
praga-quart.jogargar.es {
    root * /etc/caddy/sites/praga-quart/dist
    encode zstd gzip
    try_files {path} /index.html
    file_server
}
```

La ruta `/etc/caddy/...` es la ruta dentro del contenedor; la ruta `volumes/proxy/caddy/sites/...` es la carpeta del host que está montada allí. No sustituyas el Caddyfile entero: conserva la configuración de Supabase y agrega el nuevo bloque.

Valida y recarga Caddy usando el contenedor de Caddy (el nombre puede variar; `docker compose ps` lo muestra):

```bash
docker compose exec caddy caddy validate --config /etc/caddy/Caddyfile
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile
```

Caddy obtiene y renueva automáticamente los certificados TLS cuando el DNS apunta a esta VPS y los puertos 80/443 son accesibles. Revisa logs si no aparece el candado HTTPS:

```bash
docker compose logs --tail=100 caddy
```

---

## 7. Compilar y publicar la web Vue

El sitio se compila en tu PC y el servidor recibe **solo `dist`**. No copies `.env.local`, `node_modules`, claves privadas ni secretos del servidor a una carpeta pública.

En PowerShell, desde el proyecto:

```powershell
cd "C:\Users\alvar\Desktop\Web Projects\PragaMenu"
npm ci
```

En `.env.local` coloca los valores de cliente indicados en la sección 4.3. Este archivo es local y no se sube a la VPS ni a GitHub. Revisa que `.gitignore` lo excluya.

Compila:

```powershell
npm run build
```

Prepara el directorio remoto (una vez):

```powershell
ssh deploy@<IP_NUEVA> "mkdir -p ~/supabase-install/supabase-project/volumes/proxy/caddy/sites/praga-quart/dist"
```

Sube el contenido de `dist`:

```powershell
scp -r .\dist\* deploy@<IP_NUEVA>:~/supabase-install/supabase-project/volumes/proxy/caddy/sites/praga-quart/dist/
```

Abre `https://praga-quart.jogargar.es` y comprueba menú, imágenes, mesa/QR y que la consola del navegador no muestre fallos de red o CORS.

### Publicar otros bares

Cada bar necesita un slug, registro DNS A y bloque Caddy. La web actual elige el menú mediante `VITE_BAR_SLUG`, así que compila una versión por bar:

1. Añade un bar en la tabla `bars` y crea sus datos con el `bar_id` correspondiente (las políticas y relaciones entre datos evitan mezclar bares).
2. Crea DNS A `<slug>.jogargar.es` → IP de la VPS.
3. Añade un bloque Caddy con el directorio `/etc/caddy/sites/<slug>/dist` y recarga Caddy.
4. En PowerShell, antes de compilar esa versión:

   ```powershell
   $env:VITE_BAR_SLUG = 'bar-nuevo'
   npm run build
   Remove-Item Env:VITE_BAR_SLUG
   ```

5. Sube su `dist` a `.../sites/bar-nuevo/dist/`.

La clave publishable puede compartirse entre los bares; no compartas credenciales administrativas ni service role. Ajusta `SITE_URL` y `ADDITIONAL_REDIRECT_URLS` para los dominios que utilicen autenticación.

---

## 8. GitHub: conservar el código sin alojar la web allí

GitHub puede seguir siendo el repositorio del **código fuente**, pero el sitio público sirve desde la VPS. Este proyecto tiene un workflow de GitHub Pages en `.github/workflows/deploy.yml`; mientras esté habilitado, puede seguir publicando una copia en Pages al hacer push.

Cuando hayas confirmado que la web funciona desde Caddy:

1. En GitHub → repositorio → **Settings → Pages**, desactiva Pages o selecciona que no publique desde el workflow.
2. Desactiva o elimina `.github/workflows/deploy.yml` si no quieres que se compile/suba una copia a Pages.
3. Mantén el repositorio privado si el código debe ser privado. Aunque el repositorio sea privado, nunca guardes secretos reales en el código o historial de Git.

---

## 9. Comprobaciones de funcionamiento y seguridad

- `https://supabase.jogargar.es` abre el acceso protegido al Studio.
- `https://praga-quart.jogargar.es` carga la web con certificado válido.
- La URL pública de API del frontend es `https://supabase.jogargar.es`.
- Las imágenes devuelven archivos del bucket `productos` y no `NoSuchBucket`.
- Un QR abre la mesa correcta y se puede enviar un pedido de prueba.
- Desde Internet solo están accesibles SSH 22, HTTP 80 y HTTPS 443.
- No hay reglas de firewall ni puertos Docker públicos para `5432`, `6543`, `8000`.
- No se subieron `.env.local`, `.env` del servidor, `service_role`, `secret key` ni clave privada SSH.
- Docker sigue funcionando después de cerrar SSH:

  ```bash
  docker compose ps
  ```

Los contenedores siguen en segundo plano; no hace falta dejar abierta una ventana de terminal ni un túnel de Cloudflare. Para la administración normal se usa SSH.

---

## 10. Copias de seguridad y cambios de VPS

Una VPS no es una copia de seguridad. Programa respaldos y guarda una copia **fuera** de la VPS (por ejemplo, en tu PC o almacenamiento de copias del proveedor). Protege el respaldo porque contiene datos y puede incluir secretos.

Desde el directorio de Supabase, una copia lógica de PostgreSQL puede hacerse así:

```bash
mkdir -p ~/supabase-backups
docker compose exec -T db pg_dump -U postgres -d postgres -Fc > ~/supabase-backups/postgres-$(date +%F).dump
```

Comprueba que el archivo existe y tiene tamaño distinto de cero, y cópialo a otro dispositivo. Guarda también de forma cifrada el `.env` y los archivos del proxy/Caddy, además de los objetos de Storage. Una copia guardada solo en la misma VPS no protege ante la pérdida del servidor.

Si migras de proveedor:

1. No canceles la VPS antigua todavía.
2. Crea la nueva VPS y repite esta guía; conserva los mismos dominios y secretos de Supabase si deseas mantener la configuración JWT y los clientes actuales.
3. Restaura la base de datos y los archivos de Storage desde los respaldos siguiendo un procedimiento de restauración probado para la misma versión de Supabase/Postgres. No improvises una restauración encima de una base con datos.
4. Copia los directorios de los sitios compilados y el Caddyfile.
5. Prueba la nueva VPS usando una entrada `hosts` local o un subdominio temporal antes de cambiar DNS.
6. Cambia los registros A de `supabase` y cada bar a la IP nueva.
7. Comprueba HTTPS, login, lectura de menú, imágenes y pedidos.
8. Mantén la VPS antigua hasta confirmar que la nueva funciona y que hay una copia recuperable.

---

## Referencias oficiales

- [Supabase: self-hosting con Docker](https://supabase.com/docs/guides/self-hosting/docker)
- [Supabase: configuración de self-hosting](https://supabase.com/docs/guides/self-hosting/configuration)
- [Caddy: automatic HTTPS](https://caddyserver.com/docs/automatic-https)
- [Ubuntu Server: OpenSSH](https://documentation.ubuntu.com/server/how-to/security/openssh-server/)
- [Ubuntu Server: UFW](https://documentation.ubuntu.com/server/how-to/security/firewalls/)
