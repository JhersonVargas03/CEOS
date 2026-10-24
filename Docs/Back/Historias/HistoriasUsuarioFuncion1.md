# ÉPICA 1.A — Autenticación y Sesión
* HU-101: Como usuario, quiero iniciar sesión con mi usuario o correo interno y contraseña, para acceder al sistema según mi rol.

Criterios de aceptación:

El campo de identificador acepta tanto usuario como correo interno, sin distinguir cuál es.
El sistema normaliza a minúsculas el usuario/correo antes de comparar, sin importar cómo lo escribió la persona.
La contraseña es sensible a mayúsculas/minúsculas (no se normaliza).
Tras 5 intentos fallidos, la cuenta se bloquea temporalmente 15 minutos.
Al bloquearse, se notifica al dueño de la cuenta por su canal vinculado ("Se detectaron intentos fallidos de acceso a tu cuenta").
Mensajes de error humanos y claros, nunca códigos técnicos crudos.

Tareas técnicas:

Modelo Usuario con campos username, correo_interno (unique, lowercase forzado a nivel de guardado).
Middleware/serializer que hace .lower() al identificador antes de la consulta.
Contador de intentos fallidos + timestamp de bloqueo en el modelo.
Task de Celery o señal que dispare notificación al superar intentos fallidos.
Endpoint POST /auth/login.
* HU-102: Como usuario, quiero que mi sesión se mantenga activa en la app móvil, para no tener que loguearme cada vez que la abro.

Criterios de aceptación:

La sesión persiste tras cerrar y volver a abrir la app (mientras no haya logout explícito o remoto).
Si el token expira, se renueva automáticamente en segundo plano si es posible.
Si la sesión ya no es válida (revocada), el usuario ve un mensaje claro y va al login, no un error genérico.

Tareas técnicas:

JWT con access_token + refresh_token.
Almacenamiento seguro del token en el dispositivo (flutter_secure_storage).
Endpoint de refresh POST /auth/refresh.
HU-103: Como usuario, quiero usar la huella/Face ID de mi celular para reingresar rápido, sin escribir usuario/contraseña cada vez.

Criterios de aceptación:

Disponible solo después de un primer login exitoso con usuario/contraseña.
Si el biométrico local falla o no está disponible, siempre debe existir la opción de volver al login manual.
Esto es autenticación local del dispositivo, no reemplaza el token de sesión del backend.

Tareas técnicas:

Integración local_auth en Flutter.
Flag local (no en backend) de "biométrico habilitado" por dispositivo.
* HU-104: Como administrador o superadmin, quiero cerrar la sesión de un usuario remotamente, para revocar su acceso sin necesitar su dispositivo físico.

Criterios de aceptación:

Acción disponible desde el panel de gestión de usuarios.
Al ejecutarse, el token/refresh_token de ese usuario se invalida inmediatamente en el backend.
La próxima acción del usuario en la app (aunque tenga sesión "abierta" localmente) es rechazada y lo manda al login.

Tareas técnicas:

Tabla/blacklist de tokens revocados o versión de sesión por usuario (session_version que se incrementa al revocar).
Endpoint POST /admin/usuarios/{id}/cerrar-sesion.
Validación de session_version en cada request autenticado.
# ÉPICA 1.B — Roles y Permisos Dinámicos
* HU-105: Como superadmin, quiero crear y editar roles con permisos personalizados, para adaptar el sistema a como la clínica organiza a su personal.

Criterios de aceptación:

Pantalla tipo tabla: roles a la izquierda, permisos disponibles con checkboxes a la derecha.
Se pueden crear roles nuevos con nombre libre (ej. "Esteticista", "Asistente").
Los roles de fábrica (Administrador, GestorInventario, Doctor) existen desde el inicio pero son editables, excepto Superadmin.
El rol Superadmin no se puede editar, duplicar, eliminar ni asignar a otro usuario (es único, es tu cuenta).

Tareas técnicas:

Modelos Rol, Permiso, RolPermiso (M2M).
Seed inicial con roles y permisos de fábrica.
Endpoint CRUD /admin/roles.
Restricción a nivel de backend (no solo frontend) que impida modificar el rol Superadmin.
* HU-106: Como superadmin o administrador, quiero asignar uno o varios roles a un usuario, para reflejar cómo trabaja realmente esa persona en la clínica.

Criterios de aceptación:

Un usuario puede tener 1 o varios roles simultáneamente.
Los permisos efectivos del usuario son la unión de los permisos de todos sus roles asignados.
Cambios de rol aplican de inmediato (no requieren que el usuario vuelva a loguearse, o si técnicamente sí lo requieren, debe notificársele).

Tareas técnicas:

Modelo UsuarioRol (M2M entre Usuario y Rol).
Función obtener_permisos_efectivos(usuario) que calcula la unión de permisos.
Invalidar caché de permisos del usuario al cambiar su(s) rol(es).
* HU-107: Como sistema, debo degradar automáticamente los permisos de un usuario desactivado a "solo lectura de su propio historial", sin importar qué rol tenía.

Criterios de aceptación:

Si usuario.activo == false, sus permisos reales se ignoran y se reemplazan por: ver_mi_historial, ver_mis_reportes.
El usuario desactivado puede loguearse con su contraseña normal (no está bloqueado, solo restringido).
No puede registrar entradas/salidas, solicitar material, ni acceder a ninguna pantalla fuera de su historial/reportes propios.
Esto se valida en el backend (middleware), no solo ocultando botones en el frontend.

Tareas técnicas:

Middleware de autorización que chequea usuario.activo antes de aplicar permisos de rol.
Set fijo de permisos "modo congelado" a nivel de constante en backend.
Tests específicos para asegurar que un usuario desactivado no puede saltarse esto vía API directa.
# ÉPICA 1.C — Gestión de Cuentas (Panel Administrador/Superadmin)
* HU-108: Como administrador o superadmin, quiero crear una cuenta de usuario nuevo, para dar acceso al sistema a personal de la clínica.

Criterios de aceptación:

Formulario: nombre completo, usuario, correo interno, teléfono, rol(es), canal de notificación preferido.
El sistema genera una contraseña temporal (no la elige el admin).
Usuario y correo se guardan normalizados en minúsculas.
Al finalizar, se le indica al admin cómo comunicar el acceso inicial al nuevo usuario (ej. mostrar la contraseña temporal una sola vez en pantalla para que la copie/comparta).

Tareas técnicas:

Endpoint POST /admin/usuarios.
Generador de contraseña temporal segura.
Validación de unicidad de usuario/correo (case-insensitive).
* HU-109: Como usuario nuevo, en mi primer login quiero cambiar mi contraseña temporal y vincular mi Telegram y mi número de teléfono, para poder usar el sistema con normalidad y tener recuperación de contraseña disponible.

Criterios de aceptación:

El primer login es un flujo obligatorio de 3 pasos: (1) cambiar contraseña, (2) vincular Telegram, (3) confirmar número de teléfono con un código de verificación enviado a ese número.
El usuario no puede saltarse ningún paso ni acceder al resto del sistema hasta completarlos todos.
La confirmación del teléfono se hace con un código de verificación (no se confía en lo que tipeó el administrador al crear la cuenta).
Vincular Telegram es obligatorio, no opcional.

Tareas técnicas:

Flag primer_login_completado en el modelo Usuario.
Endpoint para cambio de contraseña obligatorio.
Flujo de vinculación de Telegram (deep link al bot + webhook que recibe el /start y guarda chat_id).
Endpoint de envío y verificación de OTP para confirmar el teléfono.
* HU-110: Como administrador o superadmin, quiero editar el rol o desactivar/reactivar una cuenta, para mantener actualizado quién tiene acceso.

Criterios de aceptación:

Nunca se elimina un usuario en duro, solo se desactiva/reactiva (activo: true/false).
Al desactivar, se aplica automáticamente HU-107 (degradación de permisos).
Al reactivar, el usuario recupera los permisos de su(s) rol(es) asignados.

Tareas técnicas:

Endpoint PATCH /admin/usuarios/{id} (rol, estado).
Registrar en auditoría cada cambio de estado/rol.
# ÉPICA 1.D — Notificaciones y Canal de Comunicación
* HU-111: Como usuario, quiero vincular mi cuenta de Telegram en el primer login, para poder recibir alertas y códigos de recuperación.

Criterios de aceptación:

Flujo guiado con pasos visuales (instalar Telegram si no lo tiene → tocar botón → /start en el bot → confirmación en la app).
Confirmación visual clara cuando la vinculación fue exitosa.
Es un paso obligatorio dentro de HU-109, no una función aislada opcional.

Tareas técnicas:

Bot de Telegram registrado con @BotFather.
Webhook que recibe /start con un parámetro único (deep link) que identifica a qué usuario del sistema pertenece.
Guardar chat_id en el modelo Usuario.
* HU-112: Como superadmin, quiero definir desde un panel qué canal de mensajería está activo en el sistema (Telegram o WhatsApp), para poder cambiarlo sin tocar código cuando decidamos habilitar WhatsApp.

Criterios de aceptación:

Pantalla simple en el panel de Superadmin con selector: "Canal activo: Telegram / WhatsApp".
Todo el sistema (alertas, OTP de recuperación, notificaciones) usa el canal que esté marcado como activo en ese momento, sin importar qué canal prefiera cada usuario individualmente.
Cambiar el canal activo no requiere despliegue ni cambios de código, es una config en base de datos.

Tareas técnicas:

Modelo ConfiguracionSistema con campo canal_mensajeria_activo.
El NotificationService abstracto lee este valor antes de decidir qué cliente usar (Telegram vs WhatsApp/Twilio).
Endpoint PATCH /admin/config/canal-mensajeria.
# ÉPICA 1.E — Recuperación de Contraseña
* HU-113: Como usuario, quiero recuperar mi contraseña recibiendo un código por Telegram/WhatsApp, para poder acceder al sistema aunque no tenga a nadie disponible para ayudarme.

Criterios de aceptación:

Flujo de 3 pantallas: (1) ingresar usuario/correo, (2) ingresar código recibido, (3) definir nueva contraseña.
El código tiene 6 dígitos y expira a los 5-10 minutos.
Máximo 3 intentos fallidos de ingresar el código; al superarlos, debe solicitar uno nuevo.
Máximo 1 código nuevo cada 60 segundos, y máximo 5 por hora (anti-spam).
El código se envía por el canal actualmente activo (HU-112), con fallback silencioso si el preferido del usuario no coincide con el activo — el usuario no ve mensajes técnicos sobre qué canal está prendido/apagado.
Se registra en auditoría cada recuperación exitosa (fecha, hora, usuario).

Tareas técnicas:

Modelo CodigoRecuperacion (usuario, código hasheado, expiración, intentos, usado).
Endpoint POST /auth/recuperar/solicitar.
Endpoint POST /auth/recuperar/verificar.
Endpoint POST /auth/recuperar/nueva-contrasena.
Rate limiting a nivel de endpoint (por usuario e IP).
Integración con NotificationService para el envío del código.
# ÉPICA 1.F — Auditoría
* HU-114: Como sistema, debo registrar cada acción relevante de un usuario (login, cambios de inventario, aprobaciones, etc.), para mantener trazabilidad completa.

Criterios de aceptación:

Cada registro de auditoría guarda: usuario, rol usado en el momento de la acción, tipo de acción, timestamp, y opcionalmente IP/dispositivo.
Los registros de auditoría son inmutables (no se editan ni se borran, ni siquiera por el Superadmin).
Un usuario desactivado conserva 100% de su historial de auditoría visible (para él mismo en modo lectura, y para administradores).

Tareas técnicas:

Modelo RegistroAuditoria (log genérico, tipo append-only).
Middleware o decorador que registra automáticamente en las acciones marcadas como auditables.
Endpoint de consulta /usuarios/{id}/historial (respeta permisos: propio usuario o admin/superadmin).
# ÉPICA 1.G — Vista Restringida (Usuario Desactivado)
* HU-115: Como usuario desactivado, quiero poder loguearme y ver únicamente mi historial y mis reportes, para consultar mi actividad pasada aunque ya no trabaje en la clínica.

Criterios de aceptación:

El login funciona normal con su contraseña existente.
La interfaz que ve es distinta a la de un usuario activo: solo dos secciones visibles, "Mi historial" y "Mis reportes".
No hay accesos, ni siquiera deshabilitados/grisados, a ninguna otra función del sistema.

Tareas técnicas:

Frontend: layout condicional según usuario.activo, reutilizando HU-107 del backend como fuente de verdad (el frontend no decide esto por sí solo).
Pantalla dedicada "vista congelada".