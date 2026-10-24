# CEOS — Sistema de Gestión para Clínica Dental

## ¿Qué es CEOS?

CEOS es una aplicación móvil de gestión interna para una clínica dental, pensada para el personal clínico y administrativo (no para pacientes). Su primera versión se enfoca en dos pilares: **control de usuarios/roles** y **control de inventario de materiales**, con una arquitectura pensada para escalar después hacia módulos de servicios/tratamientos, historial clínico y una web de agendamiento para pacientes.

El proyecto nació de una versión anterior que se reinició para trabajar bajo un enfoque **especificación-primero**: cada módulo se piensa a fondo (funcionalidades, reglas de negocio, casos límite) antes de escribir una sola línea de código, y luego se traduce a historias de usuario y tareas atómicas de desarrollo (Scrumban).

---

## Objetivo del sistema

Resolver problemas reales del día a día de la clínica:
- Saber en todo momento qué material hay, cuánto queda y cuándo vence, sin depender de memoria o papel.
- Que cada acción (quién sacó qué material, quién aprobó una solicitud, quién cambió qué) quede registrada y sea consultable.
- Que el acceso al sistema sea seguro pero simple de usar para personal que no es técnico y trabaja con prisa entre pacientes.
- Que las alertas importantes (stock bajo, vencimientos próximos) lleguen solas, sin que alguien tenga que estar revisando manualmente.

---

## Tecnologías utilizadas

| Componente | Tecnología | Para qué sirve |
|---|---|---|
| Backend | Django + Django REST Framework | Lógica de negocio y API que consume la app móvil |
| Base de datos | PostgreSQL | Almacenamiento de todos los datos del sistema |
| Tareas programadas/asíncronas | Celery + Redis | Alertas automáticas, envío de backups, tareas en segundo plano |
| App móvil | Flutter | Interfaz que usa el personal de la clínica (Android/iOS) |
| Generación de PDFs | WeasyPrint | Reportes de inventario descargables |
| Notificaciones | Telegram (activo) + WhatsApp vía Twilio (implementado, apagado) | Alertas, códigos de recuperación de contraseña, envío de reportes/backups |

---

## Cómo está organizado el sistema (módulos)

### 1. Gestión de Usuarios y Roles
Es la base de todo lo demás. Controla quién entra al sistema y qué puede hacer.

- **Roles dinámicos, no fijos en el código**: la clínica puede crear roles a su medida (ej. `Doctor`, `GestorInventario`, `Administrador`) y definir exactamente qué permisos tiene cada uno, sin que eso requiera tocar código.
- **Un usuario puede tener varios roles** a la vez.
- **Superadmin único**: cuenta especial (del desarrollador) con privilegios totales sobre el sistema, no editable ni asignable a nadie más.
- **Login flexible**: con usuario o correo interno (ambos normalizados a minúsculas para evitar errores de tipeo), más contraseña.
- **Recuperación de contraseña sin depender de nadie disponible**: se hace mediante un código enviado por Telegram/WhatsApp al número vinculado del usuario — útil si, por ejemplo, un doctor necesita entrar en una urgencia y el administrador no está disponible.
- **Sesión persistente** en la app (no pide login constantemente) con posibilidad de **cierre de sesión remoto** desde el panel de administración.
- **Usuarios desactivados** (ej. por renuncia) no se eliminan nunca — quedan en un modo de "solo lectura" donde únicamente pueden ver su propio historial y reportes pasados, sin poder operar nada más.
- **Auditoría total**: cada acción relevante queda registrada con quién la hizo, con qué rol, y cuándo.

### 2. Inventario de Materiales
El corazón operativo del sistema.

- **Catálogo de materiales** organizado por **área** (Odontología / Estética) y **categoría** (guantes, anestesia, tubos, etc.), ambos catálogos editables por la clínica.
- **Ingreso por lotes**: cada compra de material se registra como un lote independiente con su propia fecha de caducidad, permitiendo que un mismo material tenga varios lotes con vencimientos distintos.
- **Salidas con descuento automático FEFO** (*first-expired, first-out*): al sacar material, el sistema descuenta primero del lote que vence antes, para reducir el riesgo de que algo se venza sin usarse.
- **No se permite sacar más stock del que existe**: si se intenta, el sistema lo bloquea y sugiere hacer un ajuste de inventario si el problema es un desfase entre lo físico y lo digital.
- **Ajustes de inventario trazables**: cualquier corrección de stock queda registrada con motivo, usuario y fecha — nunca se edita un lote "en duro".
- **Solicitudes de material**: el personal puede pedir reposición, diferenciando si es porque **no hay stock** o porque quiere **anticiparse** a que se agote un material de baja rotación. Cada solicitud se puede editar o cancelar mientras siga pendiente.
- **Alertas automáticas** de stock bajo mínimo y de vencimiento próximo, enviadas a los roles correspondientes (con opción de apagar el envío sin perder el cálculo interno).
- **Reportes en PDF bajo demanda** (no automáticos): por fecha, rango de fechas, o filtrados por usuario, descargables desde la app y enviables también por el canal de mensajería activo.
- **Dashboard** de materiales más usados y panel separado de materiales con solicitudes preventivas.
- **Reporte de gastos** agrupado por categoría y por material, con aviso claro cuando falta el costo registrado de algún ingreso.

### 3. Respaldo de Base de Datos
Protege la integridad de todo lo construido en los módulos anteriores.

- **Backup diario automático**, generado y enviado directo por Telegram al Superadmin — sin depender de almacenamiento propio en el servidor (útil en hostings gratuitos con disco limitado).
- **Backup manual bajo demanda**, disponible solo para el Superadmin, útil antes de cambios riesgosos como migraciones o despliegues.
- **Historial de backups** para confirmar que se están ejecutando correctamente sin depender solo de revisar el chat de Telegram.

---

## Cómo se conecta todo (flujo general)

1. El personal se autentica en la app móvil con su usuario/correo y contraseña.
2. Según su(s) rol(es), ve una interfaz distinta — cada rol solo accede a lo que le corresponde.
3. El personal con permiso registra entradas y salidas de material; el sistema mantiene el stock actualizado en tiempo real, siempre respetando las reglas de FEFO y de no permitir sobregiro.
4. Celery, en segundo plano, revisa diariamente el estado del inventario y dispara alertas automáticas cuando algo está bajo mínimo o por vencer.
5. Cuando falta stock, el personal genera solicitudes, que otro rol con permiso de aprobación resuelve — todo con notificación automática de ida y vuelta.
6. El Administrador/Superadmin puede generar reportes en PDF y consultar dashboards cuando lo necesite, sin depender de envíos programados.
7. Cada noche, el sistema respalda automáticamente toda la base de datos y se la envía al Superadmin por Telegram, como seguro ante cualquier falla.

---

## Estado actual del proyecto

| Módulo | Estado |
|---|---|
| 1. Usuarios y Roles | ✅ Especificación y tareas backend completas |
| 2. Inventario de Materiales | ✅ Especificación y tareas backend completas |
| 3. Respaldo de Base de Datos | ✅ Especificación y tareas backend completas |

**Pendiente como plus futuro:** módulo de Servicios/Tratamientos, Historial Clínico de Pacientes, y la página web de agendamiento para pacientes. La integración biométrica fue descartada.

**Próximo paso:** desarrollo del backend en entorno local (Django + PostgreSQL + Redis + Celery), siguiendo el orden de los 3 módulos ya definidos, antes de pasar al desarrollo del frontend en Flutter.
