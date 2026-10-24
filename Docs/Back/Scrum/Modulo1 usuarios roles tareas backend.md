# Módulo 1 — Gestión de Usuarios y Roles
## Desglose de Tareas Backend (Scrumban)

> Formato: Épica → Historia de Usuario → Tareas técnicas atómicas → Tarea de Test de la épica.
> Cada tarea está pensada para completarse en una sola tanda de trabajo (tamaño "ticket").

---

## ÉPICA 1.A — Autenticación y Sesión

### HU-101: Login con usuario/correo + contraseña

- [ ] **T-101.1** Crear modelo `Usuario` con campos: `username`, `correo_interno`, `password_hash`, `telefono`, `activo` (default true), `intentos_fallidos` (default 0), `bloqueado_hasta` (nullable), `session_version` (default 1).
- [ ] **T-101.2** Agregar constraint de unicidad case-insensitive para `username` y `correo_interno` (índice funcional `LOWER(username)`).
- [ ] **T-101.3** Implementar método `guardar()` / signal `pre_save` que normaliza `username` y `correo_interno` a minúsculas antes de persistir.
- [ ] **T-101.4** Crear serializer/endpoint `POST /auth/login` que reciba `identificador` + `password`.
- [ ] **T-101.5** Implementar lógica de detección: buscar por `username` normalizado O `correo_interno` normalizado (un solo query con OR).
- [ ] **T-101.6** Implementar hash y verificación de contraseña (bcrypt/argon2), confirmando que NO se normaliza a minúsculas.
- [ ] **T-101.7** Implementar contador de intentos fallidos: incrementar en cada fallo, resetear a 0 en login exitoso.
- [ ] **T-101.8** Implementar bloqueo temporal: al llegar a 5 intentos fallidos, setear `bloqueado_hasta = now + 15min` y rechazar login aunque la contraseña sea correcta durante ese lapso.
- [ ] **T-101.9** Disparar notificación (vía `NotificationService`) al usuario dueño de la cuenta cuando se activa el bloqueo por intentos fallidos.
- [ ] **T-101.10** Generar y devolver `access_token` (JWT) + `refresh_token` en login exitoso.
- [ ] **T-101.11** Definir catálogo de mensajes de error legibles (usuario no existe, contraseña incorrecta, cuenta bloqueada, cuenta inactiva) sin exponer detalles técnicos ni cuál campo falló exactamente (evitar enumeración de usuarios).
- [ ] **T-101.12** Documentar el endpoint (OpenAPI/Swagger): request, response, códigos de error.

### HU-102: Sesión persistente en app móvil

- [ ] **T-102.1** Definir tiempo de expiración de `access_token` (ej. 15-30 min) y de `refresh_token` (ej. 30 días).
- [ ] **T-102.2** Crear endpoint `POST /auth/refresh` que valide el `refresh_token` y devuelva un nuevo `access_token`.
- [ ] **T-102.3** Validar en `/auth/refresh` que el `session_version` del token coincide con el actual del usuario en base de datos (si no coincide, se rechaza — cubre el caso de cierre remoto).
- [ ] **T-102.4** Implementar manejo de expiración de `refresh_token`: respuesta clara indicando que se requiere login manual nuevamente.
- [ ] **T-102.5** Middleware de autenticación global que valida `access_token` en cada request protegido y verifica `session_version`.

### HU-103: Biométrico local (soporte backend)

- [ ] **T-103.1** Confirmar que no se requiere endpoint nuevo — el biométrico es 100% local del dispositivo y solo reutiliza el `refresh_token` ya emitido.
- [ ] **T-103.2** Asegurar que el endpoint de refresh (T-102.2) no tiene restricciones adicionales que rompan este flujo (ej. reautenticación por IP nueva no debe bloquear el reingreso biométrico normal).

### HU-104: Cierre de sesión remoto

- [ ] **T-104.1** Agregar lógica para incrementar `session_version` del usuario al ejecutar cierre remoto.
- [ ] **T-104.2** Crear endpoint `POST /admin/usuarios/{id}/cerrar-sesion` restringido a roles con permiso `gestionar_usuarios`.
- [ ] **T-104.3** Validar en el middleware (ya cubierto en T-102.3) que cualquier token con `session_version` desactualizado sea rechazado inmediatamente, sin esperar a que expire naturalmente.
- [ ] **T-104.4** Registrar en auditoría el cierre de sesión remoto (quién lo ejecutó, sobre qué usuario, cuándo).

### 🧪 T-101.T — Test de la Épica 1.A
- [ ] Suite de tests: login con username en mayúsculas/minúsculas y correo, login fallido con contraseña incorrecta (case-sensitive), bloqueo tras 5 intentos, notificación disparada en bloqueo, expiración y refresh de token, rechazo de token con `session_version` desactualizado tras cierre remoto, endpoint de cierre remoto solo accesible con permiso correcto.

---

## ÉPICA 1.B — Roles y Permisos Dinámicos

### HU-105: CRUD de roles y permisos (Superadmin)

- [ ] **T-105.1** Crear modelo `Permiso` (código único, nombre legible, descripción).
- [ ] **T-105.2** Crear modelo `Rol` (nombre, descripción, `es_superadmin` flag booleano no editable).
- [ ] **T-105.3** Crear modelo intermedio `RolPermiso` (M2M entre `Rol` y `Permiso`).
- [ ] **T-105.4** Crear seed/migración de datos con permisos base del sistema (`crear_material`, `registrar_entrada`, `registrar_salida`, `aprobar_solicitud`, `ver_reportes_globales`, `gestionar_usuarios`, `gestionar_roles`, `ver_mi_historial`, `ver_mis_reportes`, etc.).
- [ ] **T-105.5** Crear seed de roles de fábrica: Superadmin, Administrador, GestorInventario, Doctor, con sus permisos iniciales asignados.
- [ ] **T-105.6** Endpoint `GET /admin/roles` (listar roles con sus permisos).
- [ ] **T-105.7** Endpoint `POST /admin/roles` (crear rol nuevo con lista de permisos).
- [ ] **T-105.8** Endpoint `PATCH /admin/roles/{id}` (editar nombre/permisos de un rol).
- [ ] **T-105.9** Endpoint `DELETE /admin/roles/{id}` (eliminar rol, solo si no es de fábrica/superadmin y no tiene usuarios activos asignados — o reasignar antes de borrar).
- [ ] **T-105.10** Validación a nivel de backend (no solo frontend) que bloquee cualquier intento de editar/eliminar el rol Superadmin vía API directa.
- [ ] **T-105.11** Restringir todos estos endpoints al permiso `gestionar_roles` (en la práctica, solo Superadmin lo tiene).

### HU-106: Asignación de roles múltiples a usuario

- [ ] **T-106.1** Crear modelo intermedio `UsuarioRol` (M2M entre `Usuario` y `Rol`).
- [ ] **T-106.2** Endpoint `PATCH /admin/usuarios/{id}/roles` (asignar/quitar roles de un usuario).
- [ ] **T-106.3** Implementar función `obtener_permisos_efectivos(usuario)` que retorna la unión (sin duplicados) de los permisos de todos los roles del usuario.
- [ ] **T-106.4** Implementar caché en memoria (ej. Redis) de los permisos efectivos por usuario, con invalidación automática al cambiar sus roles.
- [ ] **T-106.5** Middleware/decorador `requiere_permiso(codigo_permiso)` reutilizable para proteger cualquier endpoint del sistema según los permisos efectivos calculados.

### HU-107: Degradación automática de permisos en usuario desactivado

- [ ] **T-107.1** Definir constante `PERMISOS_MODO_CONGELADO = ["ver_mi_historial", "ver_mis_reportes"]` en el backend.
- [ ] **T-107.2** Modificar `obtener_permisos_efectivos(usuario)` para que, si `usuario.activo == false`, ignore los roles asignados y retorne directamente `PERMISOS_MODO_CONGELADO`.
- [ ] **T-107.3** Test específico que intente acceder a un endpoint restringido (ej. `registrar_salida`) con un usuario desactivado autenticado válidamente, y confirme rechazo 403.
- [ ] **T-107.4** Asegurar que esta validación ocurre en el middleware/decorador central (T-106.5), no de forma duplicada o inconsistente en cada endpoint individual.

### 🧪 T-105.T — Test de la Épica 1.B
- [ ] Suite de tests: creación/edición/eliminación de roles, bloqueo de edición del rol Superadmin, asignación de múltiples roles a un usuario y cálculo correcto de permisos efectivos (unión), invalidación de caché al cambiar roles, degradación total de permisos al desactivar un usuario, e intento de bypass directo vía API con usuario desactivado.

---

## ÉPICA 1.C — Gestión de Cuentas

### HU-108: Creación de cuenta por Administrador/Superadmin

- [ ] **T-108.1** Endpoint `POST /admin/usuarios` restringido a permiso `gestionar_usuarios`.
- [ ] **T-108.2** Validar unicidad case-insensitive de `username` y `correo_interno` antes de crear.
- [ ] **T-108.3** Generar contraseña temporal aleatoria segura (longitud y complejidad mínima definida).
- [ ] **T-108.4** Guardar `primer_login_completado = false` al crear la cuenta.
- [ ] **T-108.5** Devolver la contraseña temporal en la respuesta del endpoint una única vez (no se vuelve a mostrar ni se guarda en texto plano después).
- [ ] **T-108.6** Registrar en auditoría la creación de la cuenta (quién la creó, cuándo, con qué rol inicial).

### HU-109: Flujo obligatorio de primer login

- [ ] **T-109.1** Endpoint `POST /auth/primer-login/cambiar-password` (requiere sesión temporal válida tras login con contraseña temporal).
- [ ] **T-109.2** Endpoint `POST /auth/primer-login/vincular-telegram` que genera el deep link único hacia el bot para ese usuario.
- [ ] **T-109.3** Webhook `POST /telegram/webhook` que recibe el evento `/start` con el parámetro del deep link, identifica al usuario y guarda su `chat_id`.
- [ ] **T-109.4** Endpoint `POST /auth/primer-login/enviar-otp-telefono` que envía un código de verificación al teléfono ingresado (vía canal activo).
- [ ] **T-109.5** Endpoint `POST /auth/primer-login/confirmar-telefono` que valida el OTP y marca el teléfono como confirmado.
- [ ] **T-109.6** Middleware que bloquea el acceso a cualquier endpoint del sistema (fuera de los propios de este flujo) mientras `primer_login_completado == false`.
- [ ] **T-109.7** Al completar los 3 pasos (password + telegram + teléfono), setear `primer_login_completado = true` y emitir tokens normales de sesión.
- [ ] **T-109.8** Registrar en auditoría la finalización del primer login.

### HU-110: Edición/desactivación/reactivación de cuenta

- [ ] **T-110.1** Endpoint `PATCH /admin/usuarios/{id}` para editar roles, teléfono, canal preferido.
- [ ] **T-110.2** Endpoint `PATCH /admin/usuarios/{id}/estado` para alternar `activo: true/false` (sin permitir hard delete en ningún endpoint del sistema).
- [ ] **T-110.3** Al desactivar, invocar automáticamente la lógica de degradación de permisos (ya cubierta en T-107.2, se activa sola por el flag `activo`).
- [ ] **T-110.4** Al reactivar, confirmar que `obtener_permisos_efectivos` vuelve a calcular normalmente según los roles asignados.
- [ ] **T-110.5** Registrar en auditoría cada cambio de estado y de roles con timestamp y quién lo ejecutó.

### 🧪 T-108.T — Test de la Épica 1.C
- [ ] Suite de tests: creación de cuenta con validación de duplicados, generación de contraseña temporal, bloqueo de acceso al sistema mientras `primer_login_completado == false`, completar los 3 pasos del primer login en orden y fuera de orden (debe rechazar saltos), desactivación y reactivación de cuenta con verificación de permisos resultantes en cada caso.

---

## ÉPICA 1.D — Notificaciones y Canal de Comunicación

### HU-111: Vinculación de Telegram

- [ ] **T-111.1** Registrar el bot en @BotFather y guardar el token en variables de entorno/secrets (nunca en código).
- [ ] **T-111.2** Implementar cliente HTTP hacia la Bot API de Telegram (`sendMessage`, manejo de errores de red/timeout).
- [ ] **T-111.3** Implementar generación de deep link único por usuario (`https://t.me/<bot>?start=<token_unico>`).
- [ ] **T-111.4** Implementar el webhook (ya descrito en T-109.3) con validación de que el `token_unico` corresponde a un usuario real y no fue usado antes.
- [ ] **T-111.5** Manejar caso de reintento: si el usuario ya tiene `chat_id` guardado y vuelve a hacer `/start`, actualizar sin duplicar registros.

### HU-112: Selector de canal activo (Superadmin)

- [ ] **T-112.1** Crear modelo `ConfiguracionSistema` (singleton) con campo `canal_mensajeria_activo` (enum: `telegram` / `whatsapp`), valor inicial `telegram`.
- [ ] **T-112.2** Endpoint `GET /admin/config` y `PATCH /admin/config/canal-mensajeria`, restringidos a permiso de Superadmin.
- [ ] **T-112.3** Implementar la interfaz `NotificationService` con métodos `enviar(usuario, mensaje)` que internamente resuelve el canal según `ConfiguracionSistema.canal_mensajeria_activo`, ignorando la preferencia individual del usuario.
- [ ] **T-112.4** Implementar `TelegramChannel` (activo) y dejar `WhatsAppChannel` (Twilio) implementado pero inactivo, ambos cumpliendo la misma interfaz.
- [ ] **T-112.5** Implementar fallback silencioso: si el canal activo falla al enviar (ej. error de red), registrar el fallo en logs internos sin exponer detalles técnicos al usuario final.
- [ ] **T-112.6** Cachear el valor de `canal_mensajeria_activo` con invalidación inmediata al cambiarlo desde el endpoint (para no golpear la base de datos en cada envío).

### 🧪 T-111.T — Test de la Épica 1.D
- [ ] Suite de tests: generación y validación de deep link, guardado correcto de `chat_id` vía webhook simulado, cambio de canal activo desde config y verificación de que `NotificationService` efectivamente enruta al canal correcto tras el cambio, comportamiento ante fallo simulado de envío (no debe romper el flujo que lo invocó).

---

## ÉPICA 1.E — Recuperación de Contraseña

### HU-113: Recuperación vía código por canal activo

- [ ] **T-113.1** Crear modelo `CodigoRecuperacion` (usuario, código hasheado, `creado_en`, `expira_en`, `intentos_fallidos`, `usado` booleano).
- [ ] **T-113.2** Endpoint `POST /auth/recuperar/solicitar` (recibe identificador, busca usuario, genera código de 6 dígitos).
- [ ] **T-113.3** Implementar expiración del código (5-10 min) validada en el momento de verificación, no solo al generarlo.
- [ ] **T-113.4** Implementar rate limiting: máximo 1 solicitud de código cada 60 segundos y máximo 5 por hora, por usuario.
- [ ] **T-113.5** Enviar el código vía `NotificationService` (reutilizando la Épica 1.D), sin revelar en la respuesta del endpoint si el identificador existe o no (evitar enumeración de usuarios).
- [ ] **T-113.6** Endpoint `POST /auth/recuperar/verificar` (recibe identificador + código), valida vigencia y coincidencia.
- [ ] **T-113.7** Implementar límite de 3 intentos fallidos de verificación por código; al superarlo, invalidar el código y exigir solicitar uno nuevo.
- [ ] **T-113.8** Endpoint `POST /auth/recuperar/nueva-contrasena` (requiere haber verificado el código exitosamente en el paso anterior — usar un token temporal de corta duración como puente entre ambos pasos).
- [ ] **T-113.9** Invalidar el `CodigoRecuperacion` (marcar `usado = true`) inmediatamente tras el cambio exitoso de contraseña.
- [ ] **T-113.10** Registrar en auditoría cada recuperación exitosa (usuario, fecha, hora, canal usado).

### 🧪 T-113.T — Test de la Épica 1.E
- [ ] Suite de tests: solicitud y expiración del código, rate limiting de solicitudes, 3 intentos fallidos invalidando el código, flujo completo exitoso de principio a fin, intento de reutilizar un código ya usado, y verificación de que la respuesta del endpoint no filtra si el identificador existe o no.

---

## ÉPICA 1.F — Auditoría

### HU-114: Registro de acciones relevantes

- [ ] **T-114.1** Crear modelo `RegistroAuditoria` (usuario, rol_usado_en_el_momento, tipo_accion, entidad_afectada, entidad_id, timestamp, ip, dispositivo — append-only, sin campos de edición).
- [ ] **T-114.2** Implementar decorador/mixin reutilizable `@auditable(tipo_accion)` para marcar qué endpoints generan registro automático.
- [ ] **T-114.3** Aplicar el decorador a las acciones ya identificadas: login, cambios de estado de usuario, cambios de roles, creación de cuentas, recuperación de contraseña exitosa, cierre de sesión remoto (y queda abierto para módulos futuros de inventario).
- [ ] **T-114.4** Bloquear a nivel de modelo/base de datos cualquier operación de `UPDATE` o `DELETE` sobre `RegistroAuditoria` (permisos de base de datos o validación explícita en el ORM).
- [ ] **T-114.5** Endpoint `GET /usuarios/{id}/historial` con paginación, respetando que solo el propio usuario o alguien con permiso `ver_reportes_globales`/`gestionar_usuarios` puede consultarlo.

### 🧪 T-114.T — Test de la Épica 1.F
- [ ] Suite de tests: verificar que cada acción marcada como auditable efectivamente genera un registro con los datos correctos, intento de editar/borrar un registro de auditoría (debe fallar), control de acceso al endpoint de historial (usuario propio vs. usuario ajeno sin permisos vs. admin).

---

## ÉPICA 1.G — Vista Restringida (Usuario Desactivado)

### HU-115: Acceso congelado para usuario desactivado

- [ ] **T-115.1** Confirmar que el login (HU-101) no rechaza a usuarios con `activo == false`, solo continúa el flujo normal de emisión de tokens.
- [ ] **T-115.2** Endpoint de "perfil/estado de sesión" (`GET /auth/me`) que devuelva explícitamente `activo: false` y la lista de permisos efectivos (ya reducidos por T-107.2), para que el frontend pueda armar la vista congelada sin adivinar nada.
- [ ] **T-115.3** Confirmar que los endpoints de historial y reportes propios (`ver_mi_historial`, `ver_mis_reportes`) responden con normalidad para un usuario desactivado, ya que están dentro de su set de permisos congelado.
- [ ] **T-115.4** Test de integración que simule un usuario desactivado intentando acceder secuencialmente a cada endpoint protegido del módulo (registrar entrada, registrar salida, aprobar solicitud, gestionar usuarios, gestionar roles) y confirme rechazo 403 en todos.

### 🧪 T-115.T — Test de la Épica 1.G
- [ ] Suite de tests: login exitoso de usuario desactivado, respuesta correcta de `GET /auth/me` indicando estado y permisos reducidos, acceso permitido solo a historial/reportes propios, y rechazo consistente en el resto de endpoints del sistema (barrido completo, no solo casos puntuales).

---

## Resumen de cobertura de testing por épica

| Épica | Tarea de test | Enfoque principal |
|---|---|---|
| 1.A | T-101.T | Login, bloqueo por intentos, sesión, cierre remoto |
| 1.B | T-105.T | Roles/permisos dinámicos, degradación por desactivación |
| 1.C | T-108.T | Creación de cuenta, primer login obligatorio en 3 pasos |
| 1.D | T-111.T | Vinculación Telegram, selector de canal activo |
| 1.E | T-113.T | Recuperación de contraseña completa, rate limiting |
| 1.F | T-114.T | Integridad y control de acceso de auditoría |
| 1.G | T-115.T | Barrido de accesos de usuario desactivado |
