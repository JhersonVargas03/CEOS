# 📖 Guía Integral de Funcionamiento del Sistema CEOS
**Sistema de Gestión de Inventario y Operaciones Clínicas Móvil**

---

## 1. 🌟 Visión General y Propósito

El sistema **CEOS** es una plataforma integral diseñada para clínicas odontológicas y estéticas que optimiza la gestión del inventario de materiales e insumos, la trazabilidad de consumo médico con criterio **FEFO** (*First Expired, First Out*), el control estricto de accesos mediante **RBAC dinámico**, y la seguridad operativa con **respaldos automatizados** y **alertas multicanal (Telegram / WhatsApp)**.

---

## 2. 🏛️ Arquitectura Tecnológica

```
┌─────────────────────────────────────────────────────────────┐
│                   App Móvil (Flutter / Dart)               │
│  - State Management: Riverpod 2.x                           │
│  - Routing & Guards: GoRouter                               │
│  - HTTP Client: Dio + AuthInterceptor (JWT Refresh)         │
│  - Storage Seguro: FlutterSecureStorage                     │
│  - UI System: CeosTheme + Phosphor Icons                    │
└──────────────────────────────┬──────────────────────────────┘
                               │ HTTPS / JSON REST API
┌──────────────────────────────▼──────────────────────────────┐
│                  Backend (Django 5.1 / DRF)                 │
│  - Autenticación: SimpleJWT + Session Version Middleware    │
│  - Base de Datos: SQLite (Desarrollo) / PostgreSQL (Prod)   │
│  - Tareas Asíncronas: Celery + Redis                         │
│  - Generación de Documentos: WeasyPrint (PDF)               │
│  - Mensajería & Alertas: Telegram Bot API / Twilio          │
└─────────────────────────────────────────────────────────────┘
```

### Componentes Clave:
- **Backend**: API REST estructurada en aplicaciones modulares (`usuarios`, `inventario`, `backup`, `notificaciones`, `auditoria`).
- **Frontend Móvil**: Cliente multiplataforma optimizado para Android, iOS y Linux Desktop con soporte offline de catálogos y skeletons visuales para evitar parpadeos de interfaz.

---

## 3. 👥 Roles de Usuario y Matriz de Permisos (RBAC)

El sistema cuenta con 4 roles de fábrica y soporte para creación de roles personalizados:

| Rol | Descripción | Permisos Principales |
|---|---|---|
| **Superadmin** 👑 | Administrador supremo del sistema y servidor. | Control total, backups manuales y programados, auditoría global, configuración de mensajería y gestión de roles. |
| **Administrador** 🏢 | Administrador operativo de la clínica. | Gestión de usuarios, asignación de roles, catálogo de materiales, aprobación de solicitudes y reportes financieros. |
| **GestorInventario** 📦 | Encargado del almacén y suministros. | Gestión de catálogo, ingreso de lotes, ajustes de stock manuales, resolución de solicitudes de reposición. |
| **Doctor** 🩺 | Personal médico y asistencial. | Consulta de stock disponible, registro de salidas con descuento FEFO, solicitud de material y visualización de historial propio. |

---

## 4. 🚀 Módulos Funcionales

### 4.1. Módulo de Usuarios y Seguridad (`apps/usuarios`)
- **Autenticación Unificada**: Login con `username` o `correo_interno` (búsqueda insensible a mayúsculas/minúsculas).
- **Control de Intentos y Bloqueo**: Al 5º intento fallido consecutivo, la cuenta se bloquea por 15 minutos y se dispara una alerta al canal vinculado.
- **Flujo de Primer Login (Stepper Obligatorio)**:
  1. *Cambio de contraseña*: Validación interactiva en vivo (mínimo 8 caracteres, mayúscula, minúscula, número y símbolo). No requiere reingresar la contraseña temporal previa.
  2. *Vinculación con Telegram*: Deep link con token único para recibir alertas y backups.
  3. *Confirmación telefónica*: Validación mediante código OTP de 6 dígitos con rate limit de 60 segundos.
- **Validación y Normalización Telefónica (Bolivia +591)**:
  - Formato predeterminado y exclusivo de Bolivia (+591).
  - Solo solicita el número de 8 dígitos (celulares comenzando en 6 o 7; fijos en 2, 3 o 4).
  - Normaliza automáticamente en backend y app al estándar internacional `+591XXXXXXXX`.
- **Cierre de Sesión Remoto**: Incremento de `session_version` que invalida en milisegundos todos los tokens JWT emitidos previamente en otros dispositivos.

---

### 4.2. Módulo de Inventario de Materiales (`apps/inventario`)
- **Catálogo de Áreas y Categorías con Íconos Phosphor**:
  - Catálogo de íconos curado consultable en `GET /inventario/iconos-disponibles`.
  - Fallback visual automático a `'package'` si no se especifica ícono.
  - Validación en backend para rechazar identificadores de ícono no permitidos.
- **Gestión de Lotes y Despacho FEFO**:
  - Cada lote registra código, fecha de vencimiento, proveedor, costo unitario y cantidad.
  - El endpoint de salidas (`POST /inventario/salidas`) calcula automáticamente el descuento priorizando los lotes con fecha de caducidad más cercana.
- **Ajustes Manuales Trazables**:
  - Permite corregir discrepancias físicas justificando el motivo (`merma`, `danio`, `conteo_fisico`, etc.), registrando auditoría inmutable.
- **Solicitudes de Reposición**:
  - Doctores y gestores pueden solicitar insumos indicando urgencia y motivo (preventivo o por rotura de stock).
  - Flujo de resolución: `PENDIENTE` → `APROBADA` o `RECHAZADA` (con comentario obligatorio).
- **Dashboard y Reportes Financieros**:
  - Ranking de materiales más consumidos con filtros de fecha y área.
  - Monitoreo de reposición preventiva.
  - Reporte de gastos acumulados agrupado por categoría y material con detección de registros con costo incompleto.
  - Generación de reportes en PDF y envío directo al chat de Telegram del solicitante.

---

### 4.3. Módulo de Respaldo de Base de Datos (`apps/backup`)
- **Respaldo Diario Automático**: Tarea programada en Celery Beat que genera un dump comprimido en `gzip` (`backup_ceos_YYYY-MM-DD_HHMMSS.sql.gz`).
- **Envío por Telegram**: Transmisión inmediata como documento adjunto al chat privado del Superadmin.
- **Eliminación Segura**: Borrado automático del archivo del disco local del servidor inmediatamente después de confirmar la recepción en Telegram.
- **Respaldo Manual Bajo Demanda**: Endpoint `POST /admin/backup/generar` restringido exclusivamente al Superadmin.
- **Historial y Auditoría**: Bitácora completa de respaldos con fecha, tamaño, duración, origen (`AUTOMATICO` / `MANUAL`) y estado.

---

### 4.4. Módulo de Notificaciones y Auditoría (`apps/notificaciones` & `apps/auditoria`)
- **Selector de Canal Activo**: Configuración en caliente para enrutar mensajes por Telegram o WhatsApp.
- **Notificaciones In-App**: Centro de notificaciones en la app móvil para alertas de stock bajo, solicitudes resueltas y bloqueos de seguridad.
- **Bitácora de Auditoría Global**: Registro de dirección IP, usuario, timestamp y payload de cada acción crítica ejecutada en el sistema.

---

## 5. 💻 Guía de Puesta en Marcha y Pruebas en Local

### Paso 1: Configurar el Backend

1. **Acceder al directorio del backend y activar el entorno virtual:**
   ```bash
   cd /home/v4/Ceos/Backend
   source .venv/bin/activate
   ```

2. **Verificar o personalizar las variables de entorno en `.env`:**
   En `/home/v4/Ceos/Backend/.env`:
   ```env
   SECRET_KEY=django-insecure-ceos-backend-super-secret-key-2026
   DEBUG=True
   ALLOWED_HOSTS=*

   # Credenciales del Superusuario inicial
   DJANGO_SUPERUSER_USERNAME=admin
   DJANGO_SUPERUSER_EMAIL=admin@clinica.com
   DJANGO_SUPERUSER_PASSWORD=Admin1234!

   # Telegram Bot
   TELEGRAM_BOT_TOKEN=8877170293:AAGok6c8bQMhnFnLt-9FGOXUNwlpCRqVtn0
   TELEGRAM_BOT_NAME=Ceos_Clibot
   TELEGRAM_WEBHOOK_SECRET=ceos_telegram_secret_token_key_2026
   ```

3. **Inicializar la base de datos y superusuario con un solo comando:**
   ```bash
   python setup_db.py
   ```
   *(Este comando aplica migraciones, carga roles/permisos iniciales y crea o actualiza las credenciales del Superadmin según el `.env`)*.

4. **Iniciar el servidor backend:**
   ```bash
   python manage.py runserver 0.0.0.0:8000
   ```
   El backend responderá en: `http://localhost:8000/api`

---

### Paso 2: Compilar y Ejecutar la App Móvil (Flutter)

1. **Acceder al directorio del proyecto móvil:**
   ```bash
   cd /home/v4/Ceos/movil
   ```

2. **Ejecutar la app según el entorno de prueba deseado:**

   - **En Linux Desktop (Recomendado y directo en Manjaro/Linux):**
     ```bash
     flutter run -d linux
     ```

   - **En Navegador Web (Chromium / Chrome):**
     ```bash
     CHROME_EXECUTABLE=/usr/bin/chromium flutter run -d chrome
     # O si utilizas Brave:
     # CHROME_EXECUTABLE=/usr/bin/brave flutter run -d chrome
     ```

   - **En Emulador Android:**
     ```bash
     flutter run -d android --dart-define=API_URL=http://10.0.2.2:8000/api
     ```

   - **En Dispositivo Físico (mismo WiFi que la PC):**
     ```bash
     flutter run -d <id_dispositivo> --dart-define=API_URL=http://<IP_DE_TU_PC>:8000/api
     ```

---

### Paso 3: Iniciar Sesión en la App
- **Identificador / Correo:** `admin` o `admin@clinica.com`
- **Contraseña:** `Admin1234!`

---

## 6. 🧪 Verificación de Suites de Pruebas

### Pruebas del Backend (Django)
Para ejecutar la suite completa de 79 tests automatizados:
```bash
cd /home/v4/Ceos/Backend
source .venv/bin/activate
python manage.py test
```
*Resultado: **79 test cases passing al 100%**.*

### Pruebas del Frontend Móvil (Flutter)
Para ejecutar el análisis estático y la suite de tests de widgets y lógica:
```bash
cd /home/v4/Ceos/movil
flutter analyze
flutter test
```
*Resultado: **0 errores de compilación y 14 test cases passing al 100%**.*
