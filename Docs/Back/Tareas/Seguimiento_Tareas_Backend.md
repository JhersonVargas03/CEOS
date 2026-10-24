# Estado y Seguimiento de Tareas Backend (CEOS)

Este documento contiene el inventario general de tareas del backend organizadas por **Módulo**, **Épica** e **Historia de Usuario**. 
Cada tarea indica su estado actual (`[ ] ❌` Pendiente / `[x] ✅` Completada). Al completarse una tarea, se documenta su descripción técnica, el archivo donde se encuentra y la prueba realizada.

---

# Módulo 1: Gestión de Usuarios y Roles

## ÉPICA 1.A — Autenticación y Sesión

### Historia de Usuario HU-101: Login con usuario/correo + contraseña
- [x] ✅ **T-101.1**: Crear modelo `Usuario` con campos: `username`, `correo_interno`, `password_hash`, `telefono`, `activo` (default true), `intentos_fallidos` (default 0), `bloqueado_hasta` (nullable), `session_version` (default 1).
  - **Qué hace:** Define la entidad base de usuario con soporte de sesión persistente, contador de reintentos y bloqueo.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/models.py`
  - **Test:** `AuthEpica1ATestCase::test_t101_1_to_3_creacion_y_normalizacion_usuario`

- [x] ✅ **T-101.2**: Agregar constraint de unicidad case-insensitive para `username` y `correo_interno` (índice funcional `LOWER(username)`).
  - **Qué hace:** Garantiza que no existan nombres de usuario o correos duplicados por variaciones de mayúsculas/minúsculas.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/models.py`
  - **Test:** `AuthEpica1ATestCase::test_t101_1_to_3_creacion_y_normalizacion_usuario`

- [x] ✅ **T-101.3**: Implementar método `guardar()` / signal `pre_save` que normaliza `username` y `correo_interno` a minúsculas antes de persistir.
  - **Qué hace:** Limpia y convierte automáticamente `username` y `correo_interno` a minúsculas al guardar cualquier registro.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/models.py`
  - **Test:** `AuthEpica1ATestCase::test_t101_1_to_3_creacion_y_normalizacion_usuario`

- [x] ✅ **T-101.4**: Crear serializer/endpoint `POST /auth/login` que reciba `identificador` + `password`.
  - **Qué hace:** Expone el punto de entrada para autenticación de personal administrativo y clínico.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`, `file:///home/v4/Ceos/Backend/apps/usuarios/serializers.py`
  - **Test:** `AuthEpica1ATestCase::test_t101_4_to_6_login_exitoso_username_y_correo`

- [x] ✅ **T-101.5**: Implementar lógica de detección: buscar por `username` normalizado O `correo_interno` normalizado (un solo query con OR).
  - **Qué hace:** Permite al usuario iniciar sesión indistintamente con su alias o dirección de correo electrónico.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `AuthEpica1ATestCase::test_t101_4_to_6_login_exitoso_username_y_correo`

- [x] ✅ **T-101.6**: Implementar hash y verificación de contraseña (bcrypt/pbkdf2), confirmando que NO se normaliza a minúsculas.
  - **Qué hace:** Aplica algoritmo seguro de hash preservando estrictamente el case-sensitivity de las contraseñas.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/models.py`, `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `AuthEpica1ATestCase::test_t101_6_contrasena_case_sensitive`

- [x] ✅ **T-101.7**: Implementar contador de intentos fallidos: incrementar en cada fallo, resetear a 0 en login exitoso.
  - **Qué hace:** Lleva el registro acumulado de fallos consecutivos e invoca reseteo automático tras un ingreso válido.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/models.py`
  - **Test:** `AuthEpica1ATestCase::test_t101_7_to_9_conteo_intentos_fallidos_y_bloqueo_15min`

- [x] ✅ **T-101.8**: Implementar bloqueo temporal: al llegar a 5 intentos fallidos, setear `bloqueado_hasta = now + 15min` y rechazar login durante ese lapso.
  - **Qué hace:** Inhabilita el acceso por 15 minutos al superar el umbral de 5 errores para prevenir ataques de fuerza bruta.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/models.py`, `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `AuthEpica1ATestCase::test_t101_7_to_9_conteo_intentos_fallidos_y_bloqueo_15min`

- [x] ✅ **T-101.9**: Disparar notificación (vía `NotificationService`) al usuario dueño de la cuenta cuando se activa el bloqueo por intentos fallidos.
  - **Qué hace:** Alerta al usuario propietario a través del canal activo cuando su cuenta entra en estado de bloqueo.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/notificaciones/services.py`, `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `AuthEpica1ATestCase::test_t101_7_to_9_conteo_intentos_fallidos_y_bloqueo_15min`

- [x] ✅ **T-101.10**: Generar y devolver `access_token` (JWT) + `refresh_token` en login exitoso.
  - **Qué hace:** Retorna el par de tokens JWT embebiendo el `session_version` actual del usuario para control de sesión.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/tokens.py`
  - **Test:** `AuthEpica1ATestCase::test_t101_4_to_6_login_exitoso_username_y_correo`

- [x] ✅ **T-101.11**: Definir catálogo de mensajes de error legibles sin exponer detalles técnicos ni cuál campo falló exactamente.
  - **Qué hace:** Unifica las respuestas de error en login para evitar enumeración y descubrimiento de usuarios.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `AuthEpica1ATestCase::test_t101_6_contrasena_case_sensitive`

- [x] ✅ **T-101.12**: Documentar el endpoint (OpenAPI/Swagger): request, response, códigos de error.
  - **Qué hace:** Define la estructura DRF limpia de request/response y códigos de estado HTTP de la API.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/serializers.py`, `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `AuthEpica1ATestCase::test_t101_4_to_6_login_exitoso_username_y_correo`

### Historia de Usuario HU-102: Sesión persistente en app móvil
- [x] ✅ **T-102.1**: Definir tiempo de expiración de `access_token` (30 min) y de `refresh_token` (30 días).
  - **Qué hace:** Configura los tiempos de vida útil de tokens en SimpleJWT adaptados para aplicaciones móviles clínicas.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/config/settings.py`
  - **Test:** `AuthEpica1ATestCase::test_t102_1_to_5_refresh_token_y_session_version`

- [x] ✅ **T-102.2**: Crear endpoint `POST /auth/refresh` que valide el `refresh_token` y devuelva un nuevo `access_token`.
  - **Qué hace:** Permite a la app renovar el access_token sin solicitar la contraseña al usuario.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `AuthEpica1ATestCase::test_t102_1_to_5_refresh_token_y_session_version`

- [x] ✅ **T-102.3**: Validar en `/auth/refresh` que el `session_version` del token coincide con el actual del usuario en base de datos.
  - **Qué hace:** Invalida el refresco si el administrador ejecutó un deslogueo remoto sobre la cuenta.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `AuthEpica1ATestCase::test_t102_1_to_5_refresh_token_y_session_version`

- [x] ✅ **T-102.4**: Implementar manejo de expiración de `refresh_token`: respuesta clara indicando reautenticación manual.
  - **Qué hace:** Captura errores de expiración/firma y devuelve respuesta estructurada con código HTTP 401.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `AuthEpica1ATestCase::test_t102_1_to_5_refresh_token_y_session_version`

- [x] ✅ **T-102.5**: Middleware de autenticación global que valida `access_token` y `session_version` en cada request protegido.
  - **Qué hace:** Protege las peticiones HTTP verificando la autenticidad del token y la versión de sesión del usuario.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/authentication.py`, `file:///home/v4/Ceos/Backend/apps/usuarios/middleware.py`
  - **Test:** `AuthEpica1ATestCase::test_t102_1_to_5_refresh_token_y_session_version`

### Historia de Usuario HU-103: Biométrico local (soporte backend)
- [x] ✅ **T-103.1**: Confirmar que no se requiere endpoint nuevo (el biométrico reutiliza el `refresh_token`).
  - **Qué hace:** Se valida el diseño backend donde la autenticación biométrica en Flutter no requiere almacenamiento de huella en el servidor.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `AuthEpica1ATestCase::test_t102_1_to_5_refresh_token_y_session_version`

- [x] ✅ **T-103.2**: Asegurar que el endpoint de refresh no tiene restricciones adicionales que rompan este flujo.
  - **Qué hace:** Garantiza compatibilidad del endpoint de refresco ante cualquier cliente móvil.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `AuthEpica1ATestCase::test_t102_1_to_5_refresh_token_y_session_version`

### Historia de Usuario HU-104: Cierre de sesión remoto
- [x] ✅ **T-104.1**: Agregar lógica para incrementar `session_version` del usuario al ejecutar cierre remoto.
  - **Qué hace:** Método `incrementar_session_version()` invalida inmediatamente todos los JWT emitidos previamente.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/models.py`
  - **Test:** `AuthEpica1ATestCase::test_t104_1_to_4_cierre_sesion_remoto`

- [x] ✅ **T-104.2**: Crear endpoint `POST /admin/usuarios/{id}/cerrar-sesion` restringido a roles con permiso.
  - **Qué hace:** Expone la acción administrativa para forzar el deslogueo de cualquier usuario de la clínica.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `AuthEpica1ATestCase::test_t104_1_to_4_cierre_sesion_remoto`

- [x] ✅ **T-104.3**: Validar en el middleware que cualquier token con `session_version` desactualizado sea rechazado inmediatamente.
  - **Qué hace:** Intercepta tokens con versión de sesión desactualizada devolviendo 401 Unauthorized sin esperar expiración.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/authentication.py`
  - **Test:** `AuthEpica1ATestCase::test_t104_1_to_4_cierre_sesion_remoto`

- [x] ✅ **T-104.4**: Registrar en auditoría el cierre de sesión remoto.
  - **Qué hace:** Deja traza del comando de cierre de sesión indicando superusuario ejecutor y usuario objetivo.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `AuthEpica1ATestCase::test_t104_1_to_4_cierre_sesion_remoto`

### 🧪 Test Épica 1.A
- [x] ✅ **T-101.T**: Suite de tests para Épica 1.A (login, case insensitivity, intentos fallidos, bloqueo, refresh y cierre remoto).
  - **Qué hace:** Ejecuta suite automatizada `AuthEpica1ATestCase` comprobando todos los casos límite y de negocio.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/tests/test_auth.py`
  - **Test:** `AuthEpica1ATestCase` (6 tests unitarios pasando al 100%)

---

## ÉPICA 1.B — Roles y Permisos Dinámicos

### Historia de Usuario HU-105: CRUD de roles y permisos (Superadmin)
- [x] ✅ **T-105.1**: Crear modelo `Permiso` con campos: `codigo` (único e indexado), `nombre`, `descripcion`.
  - **Qué hace:** Representa la unidad atómica de permiso del sistema (ej. `gestionar_roles`, `registrar_salida`).
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/models.py`
  - **Test:** `RolesPermisosEpica1BTestCase::test_t105_1_to_5_seeds_permisos_y_roles_fabrica`

- [x] ✅ **T-105.2**: Crear modelo `Rol` con campos: `nombre` (único), `descripcion`, `es_superadmin` (flag booleano no editable), `es_de_fabrica`.
  - **Qué hace:** Agrupa un conjunto de permisos dinámicos asignables a los usuarios del sistema.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/models.py`
  - **Test:** `RolesPermisosEpica1BTestCase::test_t105_1_to_5_seeds_permisos_y_roles_fabrica`

- [x] ✅ **T-105.3**: Crear modelo intermedio `RolPermiso` (M2M entre `Rol` y `Permiso`).
  - **Qué hace:** Relaciona dinámicamente cada rol con su matriz de permisos configurada.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/models.py`
  - **Test:** `RolesPermisosEpica1BTestCase::test_t105_1_to_5_seeds_permisos_y_roles_fabrica`

- [x] ✅ **T-105.4**: Crear seed/migración de datos con permisos base del sistema (`gestionar_roles`, `gestionar_usuarios`, `crear_material`, `registrar_salida`, etc.).
  - **Qué hace:** Inicializa en base de datos la totalidad de permisos de la clínica.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/seeds.py`
  - **Test:** `RolesPermisosEpica1BTestCase::test_t105_1_to_5_seeds_permisos_y_roles_fabrica`

- [x] ✅ **T-105.5**: Crear seed de roles de fábrica (Superadmin, Administrador, GestorInventario, Doctor).
  - **Qué hace:** Carga los 4 roles predeterminados con sus permisos iniciales de fábrica.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/seeds.py`
  - **Test:** `RolesPermisosEpica1BTestCase::test_t105_1_to_5_seeds_permisos_y_roles_fabrica`

- [x] ✅ **T-105.6**: Endpoint `GET /admin/roles` (listar roles con sus permisos asociados).
  - **Qué hace:** Retorna el catálogo completo de roles dinámicos y sus permisos asignados.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `RolesPermisosEpica1BTestCase::test_t105_6_to_8_crud_roles_dinamicos`

- [x] ✅ **T-105.7**: Endpoint `POST /admin/roles` (crear nuevo rol dinámico con lista de permisos).
  - **Qué hace:** Permite al Superadmin dar de alta nuevos roles personalizados en tiempo de ejecución.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`, `file:///home/v4/Ceos/Backend/apps/usuarios/serializers.py`
  - **Test:** `RolesPermisosEpica1BTestCase::test_t105_6_to_8_crud_roles_dinamicos`

- [x] ✅ **T-105.8**: Endpoint `PATCH /admin/roles/{id}` (editar nombre, descripción y lista de permisos).
  - **Qué hace:** Modifica los permisos o descripción de un rol existente e invalida la caché de sus usuarios.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `RolesPermisosEpica1BTestCase::test_t105_6_to_8_crud_roles_dinamicos`

- [x] ✅ **T-105.9**: Endpoint `DELETE /admin/roles/{id}` (eliminar rol personalizado).
  - **Qué hace:** Elimina un rol dinámico validando previamente que no tenga usuarios activos asignados.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `RolesPermisosEpica1BTestCase::test_t105_9_10_proteccion_superadmin_y_de_fabrica`

- [x] ✅ **T-105.10**: Validación backend que bloquee cualquier intento de editar/eliminar el rol Superadmin o roles de fábrica vía API.
  - **Qué hace:** Impide la alteración o borrado del rol Superadmin o de fábrica devolviendo HTTP 403 Forbidden.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `RolesPermisosEpica1BTestCase::test_t105_9_10_proteccion_superadmin_y_de_fabrica`

- [x] ✅ **T-105.11**: Restringir endpoints de administración de roles al permiso `gestionar_roles`.
  - **Qué hace:** Aplica la clase de permiso `TienePermiso` protegiendo la API de administración de roles.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/permissions.py`, `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `RolesPermisosEpica1BTestCase::test_t105_6_to_8_crud_roles_dinamicos`

### Historia de Usuario HU-106: Asignación de roles múltiples a usuario
- [x] ✅ **T-106.1**: Crear modelo intermedio `UsuarioRol` (relación M2M entre `Usuario` y `Rol`).
  - **Qué hace:** Permite que un usuario posea simultáneamente múltiples roles dentro de la clínica.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/models.py`
  - **Test:** `RolesPermisosEpica1BTestCase::test_t106_1_to_4_asignacion_multiple_roles_y_union_permisos`

- [x] ✅ **T-106.2**: Endpoint `PATCH /admin/usuarios/{id}/roles` (asignar/quitar roles a un usuario).
  - **Qué hace:** Actualiza la lista de roles del usuario en un solo query atómico.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `RolesPermisosEpica1BTestCase::test_t106_1_to_4_asignacion_multiple_roles_y_union_permisos`

- [x] ✅ **T-106.3**: Implementar función `obtener_permisos_efectivos(usuario)` (unión de permisos de todos sus roles).
  - **Qué hace:** Calcula el conjunto total único de permisos sin duplicados resultantes de la combinación de roles.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/models.py`
  - **Test:** `RolesPermisosEpica1BTestCase::test_t106_1_to_4_asignacion_multiple_roles_y_union_permisos`

- [x] ✅ **T-106.4**: Implementar caché en memoria/Django cache de permisos efectivos con invalidación automática al modificar roles.
  - **Qué hace:** Almacena los permisos efectivos calculados por 1 hora e invalida la clave `permisos_efectivos_user_{id}` ante cualquier cambio.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/models.py`
  - **Test:** `RolesPermisosEpica1BTestCase::test_t106_1_to_4_asignacion_multiple_roles_y_union_permisos`

- [x] ✅ **T-106.5**: Middleware/decorador `@requiere_permiso(codigo_permiso)` y clase `TienePermiso`.
  - **Qué hace:** Ofrece un mecanismo reusable centralizado para autorizar o rechazar solicitudes según los permisos efectivos.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/permissions.py`
  - **Test:** `RolesPermisosEpica1BTestCase::test_t107_1_to_4_degradacion_permisos_usuario_desactivado`

### Historia de Usuario HU-107: Degradación automática de permisos en usuario desactivado
- [x] ✅ **T-107.1**: Definir constante `PERMISOS_MODO_CONGELADO = ["ver_mi_historial", "ver_mis_reportes"]`.
  - **Qué hace:** Establece los únicos permisos mínimos de lectura disponibles para cuentas desactivadas/congeladas.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/models.py`
  - **Test:** `RolesPermisosEpica1BTestCase::test_t107_1_to_4_degradacion_permisos_usuario_desactivado`

- [x] ✅ **T-107.2**: Modificar `obtener_permisos_efectivos(usuario)` para que retorne directamente `PERMISOS_MODO_CONGELADO` si `activo == False`.
  - **Qué hace:** Fuerza la degradación inmediata de todos los permisos asignados si la cuenta está inactiva.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/models.py`
  - **Test:** `RolesPermisosEpica1BTestCase::test_t107_1_to_4_degradacion_permisos_usuario_desactivado`

- [x] ✅ **T-107.3**: Test específico de rechazo 403 al intentar acceder a endpoints restringidos con usuario desactivado.
  - **Qué hace:** Comprueba que peticiones operativas realizadas por usuarios inactivos sean bloqueadas con HTTP 403.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/tests/test_roles_permisos.py`
  - **Test:** `RolesPermisosEpica1BTestCase::test_t107_1_to_4_degradacion_permisos_usuario_desactivado`

- [x] ✅ **T-107.4**: Asegurar que la validación de degradación ocurre en el mecanismo de permisos central.
  - **Qué hace:** Garantiza que la degradación aplique a todas las vistas protegidas del backend sin duplicación de código.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/permissions.py`
  - **Test:** `RolesPermisosEpica1BTestCase::test_t107_1_to_4_degradacion_permisos_usuario_desactivado`

### 🧪 Test Épica 1.B
- [x] ✅ **T-105.T**: Suite de tests para Épica 1.B (CRUD roles, protección superadmin, permisos efectivos, degradación).
  - **Qué hace:** Ejecuta la suite `RolesPermisosEpica1BTestCase` validando los flujos de RBAC dinámico y seguridad.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/tests/test_roles_permisos.py`
  - **Test:** `RolesPermisosEpica1BTestCase` (5 tests unitarios pasando al 100%)

---

## ÉPICA 1.C — Gestión de Cuentas

### Historia de Usuario HU-108: Creación de cuenta por Administrador/Superadmin
- [x] ✅ **T-108.1**: Endpoint `POST /admin/usuarios` restringido a permiso `gestionar_usuarios`.
  - **Qué hace:** Expone la acción administrativa para dar de alta cuentas de usuario asignando roles.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `GestionCuentasEpica1CTestCase::test_t108_creacion_cuenta_y_password_temporal`

- [x] ✅ **T-108.2**: Validar unicidad case-insensitive de `username` y `correo_interno`.
  - **Qué hace:** Impide la duplicidad de cuentas por combinaciones de minúsculas/mayúsculas.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `GestionCuentasEpica1CTestCase::test_t108_creacion_cuenta_y_password_temporal`

- [x] ✅ **T-108.3**: Generar contraseña temporal aleatoria segura.
  - **Qué hace:** Crea un string aleatorio de 12 caracteres (letras, números y símbolos) vía `secrets`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `GestionCuentasEpica1CTestCase::test_t108_creacion_cuenta_y_password_temporal`

- [x] ✅ **T-108.4**: Guardar `primer_login_completado = False`.
  - **Qué hace:** Marca la cuenta recién creada para requerir la ejecución obligatoria del flujo de primer login.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `GestionCuentasEpica1CTestCase::test_t108_creacion_cuenta_y_password_temporal`

- [x] ✅ **T-108.5**: Devolver contraseña temporal en la respuesta una única vez.
  - **Qué hace:** Retorna la clave temporal en el payload HTTP para su entrega física o directa al personal.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `GestionCuentasEpica1CTestCase::test_t108_creacion_cuenta_y_password_temporal`

- [x] ✅ **T-108.6**: Registrar en auditoría la creación de cuenta.
  - **Qué hace:** Graba en `RegistroAuditoria` la acción `CREACION_USUARIO` con ID y username.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/auditoria/services.py`, `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `GestionCuentasEpica1CTestCase::test_t108_creacion_cuenta_y_password_temporal`

### Historia de Usuario HU-109: Flujo obligatorio de primer login
- [x] ✅ **T-109.1**: Endpoint `POST /auth/primer-login/cambiar-password`.
  - **Qué hace:** Valida la clave temporal recibida y permite definir la clave definitiva del usuario.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `GestionCuentasEpica1CTestCase::test_t109_flujo_primer_login_y_middleware_bloqueo`

- [x] ✅ **T-109.2**: Endpoint `POST /auth/primer-login/vincular-telegram` (generar token y deep link).
  - **Qué hace:** Genera un token único y el deep link de vinculación `https://t.me/CEOSBot?start=TOKEN`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `GestionCuentasEpica1CTestCase::test_t109_flujo_primer_login_y_middleware_bloqueo`

- [x] ✅ **T-109.3**: Webhook `POST /telegram/webhook` (recibe `/start TOKEN`).
  - **Qué hace:** Procesa el comando enviado al bot de Telegram y registra el `telegram_chat_id` del usuario.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `GestionCuentasEpica1CTestCase::test_t109_flujo_primer_login_y_middleware_bloqueo`

- [x] ✅ **T-109.4**: Endpoint `POST /auth/primer-login/enviar-otp-telefono`.
  - **Qué hace:** Genera un OTP numérico de 6 dígitos con 10 min de validez y lo despacha por SMS/notificación.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `GestionCuentasEpica1CTestCase::test_t109_flujo_primer_login_y_middleware_bloqueo`

- [x] ✅ **T-109.5**: Endpoint `POST /auth/primer-login/confirmar-telefono`.
  - **Qué hace:** Compara el OTP ingresado y marca `telefono_verificado = True`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `GestionCuentasEpica1CTestCase::test_t109_flujo_primer_login_y_middleware_bloqueo`

- [x] ✅ **T-109.6**: Middleware `PrimerLoginBloqueoMiddleware` que restringe accesos mientras `primer_login_completado == False`.
  - **Qué hace:** Rechaza cualquier petición a endpoints operativos con HTTP 403 hasta completar la configuración.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/middleware.py`
  - **Test:** `GestionCuentasEpica1CTestCase::test_t109_flujo_primer_login_y_middleware_bloqueo`

- [x] ✅ **T-109.7**: Endpoint `POST /auth/primer-login/finalizar` y emisión de tokens normales.
  - **Qué hace:** Valida la culminación de pasos, cambia `primer_login_completado = True` y emite tokens JWT.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `GestionCuentasEpica1CTestCase::test_t109_flujo_primer_login_y_middleware_bloqueo`

- [x] ✅ **T-109.8**: Registrar en auditoría la finalización del primer login.
  - **Qué hace:** Asienta el evento `PRIMER_LOGIN_FINALIZADO` en la base de datos de auditoría.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `GestionCuentasEpica1CTestCase::test_t109_flujo_primer_login_y_middleware_bloqueo`

### Historia de Usuario HU-110: Edición/desactivación/reactivación de cuenta
- [x] ✅ **T-110.1**: Endpoint `PATCH /admin/usuarios/{id}` (editar datos de usuario).
  - **Qué hace:** Actualiza campos administrativos del usuario registrando el cambio.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `GestionCuentasEpica1CTestCase::test_t110_edicion_desactivacion_reactivacion_cuenta`

- [x] ✅ **T-110.2**: Endpoint `PATCH /admin/usuarios/{id}/estado` (alternar activo/inactivo).
  - **Qué hace:** Cambia el flag `activo` e incrementa `session_version` en caso de desactivación.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `GestionCuentasEpica1CTestCase::test_t110_edicion_desactivacion_reactivacion_cuenta`

- [x] ✅ **T-110.3**: Activar degradación de permisos al desactivar (`activo = False`).
  - **Qué hace:** Restringe los permisos calculados a `PERMISOS_MODO_CONGELADO` e invalida la caché.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/models.py`
  - **Test:** `GestionCuentasEpica1CTestCase::test_t110_edicion_desactivacion_reactivacion_cuenta`

- [x] ✅ **T-110.4**: Restaurar cálculo normal de permisos al reactivar (`activo = True`).
  - **Qué hace:** Reestablece el cálculo de unión de permisos dinámicos asignados a sus roles.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/models.py`
  - **Test:** `GestionCuentasEpica1CTestCase::test_t110_edicion_desactivacion_reactivacion_cuenta`

- [x] ✅ **T-110.5**: Registrar cambios de estado y roles en auditoría.
  - **Qué hace:** Graba eventos `DESACTIVACION_CUENTA` o `REACTIVACION_CUENTA` en la bitácora.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `GestionCuentasEpica1CTestCase::test_t110_edicion_desactivacion_reactivacion_cuenta`

- [x] ✅ **T-110.6**: Campo `nombre_completo` en modelo `Usuario` y serializers administrativos.
  - **Qué hace:** Agrega soporte para almacenar el nombre real/completo de la persona tanto en administración como en perfil propio.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/models.py`, `file:///home/v4/Ceos/Backend/apps/usuarios/serializers.py`
  - **Test:** `AuthEpica1ATestCase::test_perfil_usuario_patch_actualizacion_datos`

- [x] ✅ **T-110.7**: Endpoint `PATCH /auth/me` (Edición de perfil propio, username y cambio de contraseña).
  - **Qué hace:** Permite a cualquier usuario autenticado (incluyendo rol Doctor) actualizar su nombre de usuario `@username` a su comodidad (validación de unicidad, normalización a minúsculas y caracteres válidos), su nombre completo, teléfono (validación estricta Bolivia `+591` 8 dígitos) y cambiar su contraseña previa validación de la contraseña actual, registrando auditoría `EDICION_PERFIL_PROPIO`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`, `file:///home/v4/Ceos/Backend/apps/usuarios/serializers.py`
  - **Test:** `AuthEpica1ATestCase::test_perfil_usuario_patch_edicion_propia`

### 🧪 Test Épica 1.C
- [x] ✅ **T-108.T**: Suite de tests para Épica 1.C (creación de cuenta, primer login en 3 pasos, desactivación/reactivación).
  - **Qué hace:** Ejecuta suite `GestionCuentasEpica1CTestCase` evaluando la totalidad del flujo de cuenta.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/tests/test_gestion_cuentas.py`
  - **Test:** `GestionCuentasEpica1CTestCase` (3 tests de integración pasando al 100%)

---

## ÉPICA 1.D — Notificaciones y Canal de Comunicación

### Historia de Usuario HU-111: Vinculación de Telegram
- [x] ✅ **T-111.1**: Configurar cliente Telegram Bot API y variables de entorno `.env`.
  - **Qué hace:** Establece la conexión HTTP con la API de Telegram usando `TELEGRAM_BOT_TOKEN`, `TELEGRAM_BOT_NAME` y `TELEGRAM_WEBHOOK_SECRET`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/config/settings.py`, `file:///home/v4/Ceos/Backend/.env`
  - **Test:** `NotificacionesEpica1DTestCase::test_t111_service_y_fallback_silencioso`

- [x] ✅ **T-111.2**: Implementar `sendMessage` con HTTP nativo `urllib` y manejo resiliente de errores.
  - **Qué hace:** Despacha alertas formateadas en HTML por la Telegram Bot API capturando excepciones sin tumbar la aplicación.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/notificaciones/services.py`
  - **Test:** `NotificacionesEpica1DTestCase::test_t111_service_y_fallback_silencioso`

- [x] ✅ **T-111.3**: Generación de deep link único por usuario (`https://t.me/<BOT_NAME>?start=<TOKEN>`).
  - **Qué hace:** Construye la URL directa de redirección a Telegram para acelerar la vinculación con 1-click.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/notificaciones/services.py`
  - **Test:** `NotificacionesEpica1DTestCase::test_t111_service_y_fallback_silencioso`

- [x] ✅ **T-111.4**: Webhook `POST /api/telegram/webhook` con validación de token único de vinculación.
  - **Qué hace:** Procesa peticiones entrantes del bot asignando `telegram_chat_id` al usuario correspondiente.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `GestionCuentasEpica1CTestCase::test_t109_flujo_primer_login_y_middleware_bloqueo`

- [x] ✅ **T-111.5**: Manejo de reintentos y fallback silencioso en vinculación de Telegram.
  - **Qué hace:** Asume degradación silenciosa cuando Telegram está offline sin bloquear flujos críticos del sistema.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/notificaciones/services.py`
  - **Test:** `NotificacionesEpica1DTestCase::test_t111_service_y_fallback_silencioso`

### Historia de Usuario HU-112: Selector de canal activo (Superadmin)
- [x] ✅ **T-112.1**: Crear modelo `ConfiguracionSistema` con enum `CanalMensajeria` (`TELEGRAM`, `WHATSAPP`, `AMBOS`, `NINGUNO`).
  - **Qué hace:** Persiste el canal de salida activo preferido por la administración de la clínica.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/notificaciones/models.py`
  - **Test:** `NotificacionesEpica1DTestCase::test_t112_configuracion_canal_mensajeria_api`

- [x] ✅ **T-112.2**: Endpoints `GET /admin/config` y `PATCH /admin/config/canal-mensajeria`.
  - **Qué hace:** Permite consultar y modificar el canal activo dinámicamente en tiempo de ejecución.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/notificaciones/views.py`
  - **Test:** `NotificacionesEpica1DTestCase::test_t112_configuracion_canal_mensajeria_api`

- [x] ✅ **T-112.3**: Clase `NotificationService` centralizada.
  - **Qué hace:** Actúa como dispatcher principal enrutando notificaciones según las preferencias activas del sistema.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/notificaciones/services.py`
  - **Test:** `NotificacionesEpica1DTestCase::test_t111_service_y_fallback_silencioso`

- [x] ✅ **T-112.4**: Implementaciones `TelegramChannel` y `WhatsAppChannel` (MOCK extensible).
  - **Qué hace:** Provee la abstracción de envío modular para Telegram Bot API y Gateway de WhatsApp.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/notificaciones/services.py`
  - **Test:** `NotificacionesEpica1DTestCase::test_t111_service_y_fallback_silencioso`

- [x] ✅ **T-112.5**: Fallback silencioso ante errores de envío.
  - **Qué hace:** Captura excepciones de red logueando la falla sin detener la transacción en curso.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/notificaciones/services.py`
  - **Test:** `NotificacionesEpica1DTestCase::test_t111_service_y_fallback_silencioso`

- [x] ✅ **T-112.6**: Caché de `canal_mensajeria_activo` por 24 horas con invalidación en `save()`.
  - **Qué hace:** Optimiza el rendimiento reduciendo consultas repetitivas a la base de datos.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/notificaciones/models.py`
  - **Test:** `NotificacionesEpica1DTestCase::test_t112_configuracion_canal_mensajeria_api`

### 🧪 Test Épica 1.D
- [x] ✅ **T-111.T**: Suite de tests para Épica 1.D (Telegram webhook, canal activo, servicio de notificación).
  - **Qué hace:** Ejecuta suite `NotificacionesEpica1DTestCase` evaluando el selector de canales y fallback silencioso.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/notificaciones/tests/test_notificaciones.py`
  - **Test:** `NotificacionesEpica1DTestCase` (2 tests pasando al 100%)

---

## ÉPICA 1.E — Recuperación de Contraseña

### Historia de Usuario HU-113: Recuperación vía código por canal activo
- [x] ✅ **T-113.1**: Modelo `CodigoRecuperacion`.
  - **Qué hace:** Almacena los tokens de recuperación temporales con campo `codigo` (6 dígitos), `expiracion` (10 min), `intentos_fallidos` y `usado`. Incluye métodos `esta_vigente()` y `registrar_intento_fallido()` con bloqueo automático tras 3 intentos.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/models.py`
  - **Test:** `RecuperacionPasswordEpica1ETestCase::test_t113_flujo_completo_recuperacion_y_nueva_password`

- [x] ✅ **T-113.2**: Endpoint `POST /auth/recuperar/solicitar`.
  - **Qué hace:** Recibe un identificador (username o correo), localiza al usuario y envía el código de recuperación por el canal activo. Devuelve siempre un mensaje genérico para evitar enumeración de usuarios.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py` → `SolicitarRecuperacionView`
  - **Test:** `RecuperacionPasswordEpica1ETestCase::test_t113_solicitud_anti_enumeracion_y_rate_limiting`

- [x] ✅ **T-113.3**: Expiración del código (10 min).
  - **Qué hace:** El campo `expiracion` se establece a `now() + 10 minutos` al crear el `CodigoRecuperacion`. El método `esta_vigente()` verifica que el código no haya expirado y no esté marcado como `usado`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/models.py` → `CodigoRecuperacion.esta_vigente()`
  - **Test:** `RecuperacionPasswordEpica1ETestCase::test_t113_verificacion_codigo_y_limite_intentos_fallidos`

- [x] ✅ **T-113.4**: Rate limiting (1 solic/60s, max 5/hora).
  - **Qué hace:** Usa `django.core.cache` para imponer un cooldown de 60 segundos entre solicitudes y un contador máximo de 5 solicitudes por hora por usuario. Devuelve HTTP 429 si se supera cualquiera de los límites.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py` → `SolicitarRecuperacionView.post()`
  - **Test:** `RecuperacionPasswordEpica1ETestCase::test_t113_solicitud_anti_enumeracion_y_rate_limiting`

- [x] ✅ **T-113.5**: Envío vía `NotificationService` (sin enumeración de usuarios).
  - **Qué hace:** El código se envía a través del `NotificationService` al canal activo del sistema (Telegram/WhatsApp). La respuesta HTTP es siempre idéntica independientemente de si el usuario existe, previniendo ataques de enumeración.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py` → `SolicitarRecuperacionView`
  - **Test:** `RecuperacionPasswordEpica1ETestCase::test_t113_solicitud_anti_enumeracion_y_rate_limiting`

- [x] ✅ **T-113.6**: Endpoint `POST /auth/recuperar/verificar`.
  - **Qué hace:** Valida el identificador y el código de 6 dígitos contra el `CodigoRecuperacion` vigente del usuario. Devuelve confirmación si el código es correcto.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py` → `VerificarCodigoRecuperacionView`
  - **Test:** `RecuperacionPasswordEpica1ETestCase::test_t113_verificacion_codigo_y_limite_intentos_fallidos`

- [x] ✅ **T-113.7**: Límite de 3 intentos fallidos por código.
  - **Qué hace:** Cada código incorrecto incrementa `intentos_fallidos`. Al alcanzar 3 intentos, el código se invalida automáticamente llamando a `registrar_intento_fallido()`, que marca `usado=True` si se supera el límite.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/models.py` → `CodigoRecuperacion.registrar_intento_fallido()`
  - **Test:** `RecuperacionPasswordEpica1ETestCase::test_t113_verificacion_codigo_y_limite_intentos_fallidos`

- [x] ✅ **T-113.8**: Endpoint `POST /auth/recuperar/nueva-contrasena`.
  - **Qué hace:** Valida el identificador y el código una vez más antes de aceptar la nueva contraseña. Establece la nueva clave con `set_password()` y llama a `incrementar_session_version()` para invalidar todas las sesiones activas del usuario.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py` → `NuevaPasswordRecuperacionView`
  - **Test:** `RecuperacionPasswordEpica1ETestCase::test_t113_flujo_completo_recuperacion_y_nueva_password`

- [x] ✅ **T-113.9**: Invalidar `CodigoRecuperacion` tras cambio.
  - **Qué hace:** Una vez restablecida la contraseña, el código se marca como `usado=True` para evitar reutilización. Además, todos los códigos previos pendientes del usuario se invalidan al generar uno nuevo (`update(usado=True)`).
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py` → `NuevaPasswordRecuperacionView.post()`
  - **Test:** `RecuperacionPasswordEpica1ETestCase::test_t113_flujo_completo_recuperacion_y_nueva_password`

- [x] ✅ **T-113.10**: Registro en auditoría.
  - **Qué hace:** Cada paso del flujo de recuperación genera un registro en `RegistroAuditoria`: `SOLICITUD_RECUPERACION`, `VERIFICACION_CODIGO_RECUPERACION` y `CAMBIO_PASSWORD_RECUPERACION`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py` → todas las vistas de recuperación
  - **Test:** `RecuperacionPasswordEpica1ETestCase::test_t113_flujo_completo_recuperacion_y_nueva_password`

### 🧪 Test Épica 1.E
- [x] ✅ **T-113.T**: Suite de tests para Épica 1.E (recuperación de contraseña completa).
  - **Qué hace:** Ejecuta 3 casos de prueba: flujo completo de recuperación, anti-enumeración con rate limiting, y bloqueo tras 3 intentos fallidos. Los 3 tests pasan al 100%.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/tests/test_recuperacion_password.py`
  - **Test:** `RecuperacionPasswordEpica1ETestCase` (3 tests pasando al 100%)


---

## ÉPICA 1.F — Auditoría

### Historia de Usuario HU-114: Registro de acciones relevantes
- [x] ✅ **T-114.1**: Modelo `RegistroAuditoria` (append-only).
  - **Qué hace:** Modelo que solo permite inserts. El método `save()` lanza `PermissionError` si el registro ya tiene `pk` (update), y `delete()` lanza `PermissionError` siempre. Campos: `usuario`, `accion`, `detalles (JSON)`, `ip_address`, `fecha_hora (auto)`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/auditoria/models.py`
  - **Test:** `AuditoriaEpica1FTestCase::test_t114_1_modelo_append_only`

- [x] ✅ **T-114.2**: Decorador `@auditable(tipo_accion)`.
  - **Qué hace:** Decorador funcional reutilizable que envuelve una view function. Si la respuesta tiene código 2xx, registra automáticamente la acción en `RegistroAuditoria`. Acepta función opcional `extraer_detalles(req, res)` para capturar contexto adicional.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/auditoria/services.py` → función `auditable()`
  - **Test:** `AuditoriaEpica1FTestCase::test_t114_2_3_decorador_auditable`

- [x] ✅ **T-114.3**: Aplicar decorador a acciones clave.
  - **Qué hace:** El `AuditService.registrar_accion()` ya está aplicado directamente en todas las views críticas: `LOGIN_EXITOSO`, `LOGIN_FALLIDO`, `ACCESO_BLOQUEADO`, `CIERRE_SESION_REMOTO`, `CREACION_USUARIO`, `EDICION_USUARIO`, `DESACTIVACION_CUENTA`, `REACTIVACION_CUENTA`, `CREACION_ROL`, `EDICION_ROL`, `ELIMINACION_ROL`, `PRIMER_LOGIN_FINALIZADO`, `SOLICITUD_RECUPERACION`, `CAMBIO_PASSWORD_RECUPERACION`, `TELEGRAM_VINCULADO`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `AuditoriaEpica1FTestCase::test_t114_2_3_decorador_auditable`

- [x] ✅ **T-114.4**: Bloqueo de `UPDATE`/`DELETE` en `RegistroAuditoria`.
  - **Qué hace:** Override de `save()` y `delete()` en el modelo para lanzar `PermissionError` ante cualquier intento de modificación o eliminación, garantizando la integridad del log de auditoría a nivel ORM.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/auditoria/models.py` → `RegistroAuditoria.save()` y `RegistroAuditoria.delete()`
  - **Test:** `AuditoriaEpica1FTestCase::test_t114_1_modelo_append_only`

- [x] ✅ **T-114.5**: Endpoint `GET /usuarios/{id}/historial`.
  - **Qué hace:** Endpoint con paginación (`page`, `page_size` hasta 100). El propio usuario puede ver su historial. Un usuario con `gestionar_usuarios` o `ver_reportes_globales` puede ver el historial de cualquier usuario. Devuelve `total`, `page`, `page_size` y `results`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/auditoria/views.py` → `HistorialUsuarioView`
  - **Test:** `AuditoriaEpica1FTestCase::test_t114_5_endpoint_historial_propio`, `test_t114_5_historial_acceso_admin`, `test_t114_5_historial_acceso_denegado`, `test_t114_5_paginacion_historial`

### 🧪 Test Épica 1.F
- [x] ✅ **T-114.T**: Suite de tests para Épica 1.F (auditoría e inmutabilidad).
  - **Qué hace:** Cubre inmutabilidad del modelo (save/delete bloqueados), funcionamiento del decorador `@auditable`, acceso propio/admin/denegado al historial y paginación. 6 tests pasando al 100%.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/auditoria/tests/test_auditoria_y_vista_restringida.py`
  - **Test:** `AuditoriaEpica1FTestCase` (6 tests pasando al 100%)

---

## ÉPICA 1.G — Vista Restringida (Usuario Desactivado)

### Historia de Usuario HU-115: Acceso congelado para usuario desactivado
- [x] ✅ **T-115.1**: Confirmar login de usuarios inactivados para emisión de tokens.
  - **Qué hace:** El endpoint de login acepta credenciales de usuarios con `activo=False` y emite tokens normalmente. El control de acceso se realiza por permisos congelados, no rechazando el login.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py` → `LoginView`
  - **Test:** `VistaRestringidaEpica1GTestCase::test_t115_1_login_emite_tokens_usuario_desactivado`

- [x] ✅ **T-115.2**: Endpoint `GET /auth/me` con `activo: false` y permisos congelados.
  - **Qué hace:** El endpoint `/auth/me` devuelve `activo: false` en los datos del usuario y la lista reducida de permisos efectivos (`PERMISOS_MODO_CONGELADO`) para que el frontend pueda renderizar la vista congelada sin adivinar el estado.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py` → `PerfilUsuarioView`
  - **Test:** `VistaRestringidaEpica1GTestCase::test_t115_2_get_me_retorna_activo_false_y_permisos_congelados`

- [x] ✅ **T-115.3**: Confirmar acceso a `ver_mi_historial` y `ver_mis_reportes`.
  - **Qué hace:** La función `obtener_permisos_efectivos()` retorna `PERMISOS_MODO_CONGELADO` para usuarios con `activo=False`. Estos permisos incluyen `ver_mi_historial` y `ver_mis_reportes`, permitiendo acceso limitado de consulta.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/models.py` → `obtener_permisos_efectivos()`
  - **Test:** `VistaRestringidaEpica1GTestCase::test_t115_3_permisos_congelados_son_correctos`

- [x] ✅ **T-115.4**: Test de integración de rechazo 403 en endpoints protegidos.
  - **Qué hace:** Barrido completo de endpoints admin/operativos: `GET /admin/usuarios`, `GET /admin/roles`, `GET /admin/permisos`, `POST /admin/usuarios`. Todos devuelven 403 para el usuario desactivado.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/auditoria/tests/test_auditoria_y_vista_restringida.py`
  - **Test:** `VistaRestringidaEpica1GTestCase::test_t115_4_barrido_403_endpoints_protegidos`

### 🧪 Test Épica 1.G
- [x] ✅ **T-115.T**: Suite de tests para Épica 1.G (vista restringida).
  - **Qué hace:** Cubre login de usuario desactivado, respuesta de `/auth/me` con datos congelados, verificación de permisos efectivos y barrido de rechazo 403 en todos los endpoints protegidos. 4 tests pasando al 100%.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/auditoria/tests/test_auditoria_y_vista_restringida.py`
  - **Test:** `VistaRestringidaEpica1GTestCase` (4 tests pasando al 100%)


---

# Módulo 2: Inventario de Materiales

## ÉPICA 2.A — Catálogo de Materiales (Áreas, Categorías, Materiales)

### Historia de Usuario HU-201: CRUD de Áreas
- [x] ✅ **T-201.1**: Modelo `Area`.
  - **Qué hace:** Modelo con campos `nombre` (único e indexado), `descripcion`, `activo` (default True) y `creado_en`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/models.py`
  - **Test:** `CatalogoMaterialesEpica2ATestCase::test_hu201_crud_areas`

- [x] ✅ **T-201.2**: Endpoint `GET /inventario/areas`.
  - **Qué hace:** Devuelve el listado de todas las áreas activas registradas en la clínica.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `AreaListCreateView`
  - **Test:** `CatalogoMaterialesEpica2ATestCase::test_hu201_crud_areas`

- [x] ✅ **T-201.3**: Endpoint `POST /inventario/areas`.
  - **Qué hace:** Registra una nueva área validando unicidad de nombre (case-insensitive) y registrando la acción en auditoría.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `AreaListCreateView`
  - **Test:** `CatalogoMaterialesEpica2ATestCase::test_hu201_crud_areas`

- [x] ✅ **T-201.4**: Endpoint `PATCH /inventario/areas/{id}`.
  - **Qué hace:** Permite modificar el nombre o descripción de un área validando colisiones de nombre con otras áreas.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `AreaDetailView`
  - **Test:** `CatalogoMaterialesEpica2ATestCase::test_hu201_crud_areas`

- [x] ✅ **T-201.5**: Endpoint `DELETE /inventario/areas/{id}` (validar materiales asociados).
  - **Qué hace:** Desactiva un área (`activo=False`). Rechaza la solicitud con error 400 si el área tiene materiales vinculados.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `AreaDetailView`
  - **Test:** `CatalogoMaterialesEpica2ATestCase::test_hu201_5_bloqueo_delete_area_con_materiales`

### Historia de Usuario HU-202: CRUD de Categorías de material
- [x] ✅ **T-202.1**: Modelo `CategoriaMaterial`.
  - **Qué hace:** Modelo con campos `nombre` (único e indexado), `descripcion`, `activo` y `creado_en`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/models.py`
  - **Test:** `CatalogoMaterialesEpica2ATestCase::test_hu202_crud_categorias`

- [x] ✅ **T-202.2**: Endpoint `GET /inventario/categorias`.
  - **Qué hace:** Lista las categorías de materiales activas.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `CategoriaListCreateView`
  - **Test:** `CatalogoMaterialesEpica2ATestCase::test_hu202_crud_categorias`

- [x] ✅ **T-202.3**: Endpoint `POST /inventario/categorias`.
  - **Qué hace:** Crea una nueva categoría registrando la auditoría correspondiente.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `CategoriaListCreateView`
  - **Test:** `CatalogoMaterialesEpica2ATestCase::test_hu202_crud_categorias`

- [x] ✅ **T-202.4**: Endpoint `PATCH /inventario/categorias/{id}`.
  - **Qué hace:** Actualiza parcialmente los datos de una categoría.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `CategoriaDetailView`
  - **Test:** `CatalogoMaterialesEpica2ATestCase::test_hu202_crud_categorias`

- [x] ✅ **T-202.5**: Endpoint `DELETE /inventario/categorias/{id}`.
  - **Qué hace:** Desactiva una categoría validando que no tenga materiales asociados.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `CategoriaDetailView`
  - **Test:** `CatalogoMaterialesEpica2ATestCase::test_hu202_crud_categorias`

### Historia de Usuario HU-203: Alta de material
- [x] ✅ **T-203.1**: Modelo `Material`.
  - **Qué hace:** Modelo con relaciones a `Area` y `CategoriaMaterial`, `unidad_medida`, `stock_minimo`, `activo` y fechas.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/models.py`
  - **Test:** `CatalogoMaterialesEpica2ATestCase::test_hu203_alta_y_unicidad_material`

- [x] ✅ **T-203.2**: Endpoint `POST /inventario/materiales`.
  - **Qué hace:** Alta de un nuevo material asignándole su área y categoría.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `MaterialListCreateView`
  - **Test:** `CatalogoMaterialesEpica2ATestCase::test_hu203_alta_y_unicidad_material`

- [x] ✅ **T-203.3**: Unicidad área+categoría+nombre.
  - **Qué hace:** Restricción `unique_together = ('area', 'categoria', 'nombre')` en la base de datos y validación previa en la view.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/models.py` y `views.py`
  - **Test:** `CatalogoMaterialesEpica2ATestCase::test_hu203_alta_y_unicidad_material`

- [x] ✅ **T-203.4**: Endpoint `PATCH /inventario/materiales/{id}`.
  - **Qué hace:** Edición parcial de propiedades del material (`stock_minimo`, `unidad_medida`, `descripcion`, `activo`).
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `MaterialDetailView`
  - **Test:** `CatalogoMaterialesEpica2ATestCase::test_hu203_alta_y_unicidad_material`

- [x] ✅ **T-203.5**: Cálculo `stock_total_disponible(material)`.
  - **Qué hace:** Método `stock_total_disponible()` que suma la `cantidad_disponible` de todos los lotes activos del material.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/models.py` → `Material.stock_total_disponible()`
  - **Test:** `CatalogoMaterialesEpica2ATestCase::test_hu203_alta_y_unicidad_material`

### Historia de Usuario HU-204: Búsqueda y filtrado de materiales
- [x] ✅ **T-204.1**: Endpoint `GET /inventario/materiales` con filtros.
  - **Qué hace:** Permite filtrar por `area_id` y `categoria_id`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `MaterialListCreateView`
  - **Test:** `CatalogoMaterialesEpica2ATestCase::test_hu204_busqueda_y_filtrado_materiales`

- [x] ✅ **T-204.2**: Búsqueda case-insensitive / parcial.
  - **Qué hace:** Parámetro `q` que busca en `nombre`, `descripcion`, `area__nombre` y `categoria__nombre`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `MaterialListCreateView`
  - **Test:** `CatalogoMaterialesEpica2ATestCase::test_hu204_busqueda_y_filtrado_materiales`

- [x] ✅ **T-204.3**: Incluir stock actual y estado derivado.
  - **Qué hace:** Serializer expone `stock_disponible` y `estado_stock` ('ok', 'bajo', 'sin_stock').
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/serializers.py` → `MaterialSerializer`
  - **Test:** `CatalogoMaterialesEpica2ATestCase::test_hu204_busqueda_y_filtrado_materiales`

- [x] ✅ **T-204.4**: Índices de base de datos.
  - **Qué hace:** Agregados `models.Index` en `nombre`, `('area', 'categoria')` y `activo` en la clase `Meta` del modelo.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/models.py` → `Material.Meta`
  - **Test:** `CatalogoMaterialesEpica2ATestCase::test_hu204_busqueda_y_filtrado_materiales`

### 🧪 Test Épica 2.A
- [x] ✅ **T-201.T**: Suite de tests para Épica 2.A.
  - **Qué hace:** Suite de 5 test cases que prueban el CRUD de áreas, categorías, alta y unicidad de materiales, cálculo de stock y búsqueda/filtrado. 5 tests pasando al 100%.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/tests/test_catalogo_materiales.py`
  - **Test:** `CatalogoMaterialesEpica2ATestCase` (5 tests pasando al 100%)

---

## ÉPICA 2.B — Ingreso de Lotes (Entradas)

### Historia de Usuario HU-205: Registro de ingreso de lote
- [x] ✅ **T-205.1**: Modelo `Lote`.
  - **Qué hace:** Modelo con `material` (FK), `codigo_lote`, `cantidad_ingresada`, `cantidad_disponible`, `costo`, `costo_registrado`, `fecha_ingreso`, `fecha_caducidad`, `fecha_alerta_vencimiento` y `usuario_ingreso`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/models_lotes.py`
  - **Test:** `IngresoLotesEpica2BTestCase::test_creacion_lote_con_y_sin_costo`

- [x] ✅ **T-205.2**: Endpoint `POST /inventario/lotes`.
  - **Qué hace:** Registra la entrada de un nuevo lote de un material en el sistema. Protegido con permiso `registrar_entrada`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `LoteCreateView`
  - **Test:** `IngresoLotesEpica2BTestCase::test_creacion_lote_con_y_sin_costo`

- [x] ✅ **T-205.3**: Inicializar `cantidad_disponible = cantidad_ingresada`.
  - **Qué hace:** Al crear el lote, asigna `cantidad_disponible = cantidad_ingresada` para el posterior descuento FEFO.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `LoteCreateView`
  - **Test:** `IngresoLotesEpica2BTestCase::test_creacion_lote_con_y_sin_costo`

- [x] ✅ **T-205.4**: Manejo de `costo_registrado`.
  - **Qué hace:** Setea automáticamenete `costo_registrado = True` si se especifica un costo válido, o `False` si viene nulo.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `LoteCreateView`
  - **Test:** `IngresoLotesEpica2BTestCase::test_creacion_lote_con_y_sin_costo`

- [x] ✅ **T-205.5**: Registro en auditoría.
  - **Qué hace:** Llama a `AuditService.registrar_accion` para registrar `INGRESO_LOTE` con ID del lote, código, material y cantidad ingresada.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `LoteCreateView`
  - **Test:** `IngresoLotesEpica2BTestCase::test_registro_auditoria_ingreso_lote`

- [x] ✅ **T-205.6**: Validaciones de fechas.
  - **Qué hace:** Serializer valida que `fecha_caducidad` no sea anterior a `fecha_ingreso` y que `fecha_alerta_vencimiento` no sea posterior a `fecha_caducidad`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/serializers.py` → `LoteCreateSerializer`
  - **Test:** `IngresoLotesEpica2BTestCase::test_validacion_fechas_inconsistentes`

### Historia de Usuario HU-206: Listado de lotes por material
- [x] ✅ **T-206.1**: Endpoint `GET /inventario/materiales/{id}/lotes`.
  - **Qué hace:** Retorna el listado de lotes pertenecientes a un material, ordenados por `fecha_caducidad` ascendente.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `MaterialLotesListView`
  - **Test:** `IngresoLotesEpica2BTestCase::test_listado_lotes_ordenado_y_alerta_activa`

- [x] ✅ **T-206.2**: Campo `alerta_activa`.
  - **Qué hace:** Propiedad calculada en modelo y expuesta en serializer que indica `True` si la fecha actual alcanza o supera `fecha_alerta_vencimiento` o `fecha_caducidad`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/models_lotes.py` → `Lote.alerta_activa`
  - **Test:** `IngresoLotesEpica2BTestCase::test_listado_lotes_ordenado_y_alerta_activa`

- [x] ✅ **T-206.3**: Filtrado de lotes agotados por defecto.
  - **Qué hace:** Filtra automáticamente lotes con `cantidad_disponible > 0`. Permite incluirlos mediante el query param `incluir_agotados=true`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `MaterialLotesListView`
  - **Test:** `IngresoLotesEpica2BTestCase::test_listado_lotes_ordenado_y_alerta_activa`

### 🧪 Test Épica 2.B
- [x] ✅ **T-205.T**: Suite de tests para Épica 2.B.
  - **Qué hace:** Suite de 4 test cases que prueban el registro de lotes con y sin costo, validaciones de fechas inconsistentes, registro en auditoría y el listado de lotes por material ordenado por vencimiento con alertas y filtros. 4 tests pasando al 100%.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/tests/test_ingreso_lotes.py`
  - **Test:** `IngresoLotesEpica2BTestCase` (4 tests pasando al 100%)


---

## ÉPICA 2.C — Salidas de Material (FEFO)

### Historia de Usuario HU-207: Registro de salida con descuento automático FEFO
- [x] ✅ **T-207.1**: Modelo `MovimientoSalida`.
  - **Qué hace:** Modelo con `material` (FK), `cantidad_total`, `motivo_destino`, `usuario` (FK) y `fecha_hora`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/models_movimientos.py` → `MovimientoSalida`
  - **Test:** `SalidasFEFOEpica2CTestCase::test_salida_repartida_entre_lotes_fefo`

- [x] ✅ **T-207.2**: Modelo `MovimientoSalidaLote`.
  - **Qué hace:** Modelo intermedio que detalla la cantidad exacta descontada de cada `Lote` en una salida.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/models_movimientos.py` → `MovimientoSalidaLote`
  - **Test:** `SalidasFEFOEpica2CTestCase::test_salida_repartida_entre_lotes_fefo`

- [x] ✅ **T-207.3**: Función `calcular_distribucion_fefo()`.
  - **Qué hace:** Función que toma lotes ordenados por fecha de vencimiento (`fecha_caducidad` asc) y distribuye el descuento entre varios lotes hasta satisfacer la cantidad solicitada.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `calcular_distribucion_fefo`
  - **Test:** `SalidasFEFOEpica2CTestCase::test_salida_repartida_entre_lotes_fefo`

- [x] ✅ **T-207.4**: Endpoint `POST /inventario/salidas`.
  - **Qué hace:** Registra la salida de material descontando existencias bajo la política FEFO. Protegido con permiso `registrar_salida`. Soporta aliases de payload tanto `material` como `material_id` y `motivo` como `motivo_destino`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `SalidaCreateView` | `file:///home/v4/Ceos/Backend/apps/inventario/serializers.py` → `SalidaCreateSerializer`
  - **Test:** `SalidasFEFOEpica2CTestCase::test_salida_repartida_entre_lotes_fefo` y `test_salida_con_alias_material_id_y_motivo`

- [x] ✅ **T-207.5**: Transacción con bloqueo de fila (`select_for_update`).
  - **Qué hace:** Ejecuta la operación completa dentro de `transaction.atomic()` aplicando `select_for_update()` sobre los lotes del material para prevenir condiciones de carrera.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `SalidaCreateView`
  - **Test:** `SalidasFEFOEpica2CTestCase::test_salida_repartida_entre_lotes_fefo`

- [x] ✅ **T-207.6**: Auditoría de salida.
  - **Qué hace:** Registra en auditoría la acción `REGISTRO_SALIDA_FEFO` con ID del movimiento, material, cantidad y códigos de lotes afectados.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `SalidaCreateView`
  - **Test:** `SalidasFEFOEpica2CTestCase::test_registro_auditoria_salida_fefo`

### Historia de Usuario HU-208: Bloqueo de salida mayor al stock disponible
- [x] ✅ **T-208.1**: Validación de stock suficiente.
  - **Qué hace:** Verifica que `stock_disponible_actual >= cantidad_solicitada` antes de aplicar cualquier descuento.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `SalidaCreateView`
  - **Test:** `SalidasFEFOEpica2CTestCase::test_bloqueo_salida_mayor_a_stock_disponible`

- [x] ✅ **T-208.2**: Rollback de transacción si falla stock.
  - **Qué hace:** Aborta la transacción devolviendo HTTP 400 Bad Request sin persistir ningún cambio parcial en la base de datos.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `SalidaCreateView`
  - **Test:** `SalidasFEFOEpica2CTestCase::test_bloqueo_salida_mayor_a_stock_disponible`

- [x] ✅ **T-208.3**: Respuesta de error con flag `puede_ajustar`.
  - **Qué hace:** Incluye `stock_disponible_actual`, `cantidad_solicitada` y el flag booleano `puede_ajustar` (calculado dinámicamente según si el usuario posee el permiso `ajustar_inventario`).
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `SalidaCreateView`
  - **Test:** `SalidasFEFOEpica2CTestCase::test_verificacion_flag_puede_ajustar_segun_permiso`

### 🧪 Test Épica 2.C
- [x] ✅ **T-207.T**: Suite de tests para Épica 2.C (FEFO y concurrencia).
  - **Qué hace:** Suite de 4 test cases que prueban el reparto FEFO entre múltiples lotes, bloqueo y rollback por stock insuficiente, verificación del flag `puede_ajustar` según rol/permisos y auditoría. 4 tests pasando al 100%.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/tests/test_salidas_fefo.py`
  - **Test:** `SalidasFEFOEpica2CTestCase` (4 tests pasando al 100%)


---

## ÉPICA 2.D — Ajustes de Inventario

### Historia de Usuario HU-209: Registro de ajuste manual
- [x] ✅ **T-209.1**: Modelo `AjusteInventario`.
  - **Qué hace:** Modelo con `lote` (FK), `usuario` (FK), `cantidad_anterior`, `cantidad_nueva`, `motivo` y `fecha_hora`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/models_ajustes.py` → `AjusteInventario`
  - **Test:** `AjustesInventarioEpica2DTestCase::test_creacion_ajuste_y_actualizacion_lote`

- [x] ✅ **T-209.2**: Endpoint `POST /inventario/ajustes`.
  - **Qué hace:** Registra un ajuste manual de existencias sobre un lote específico. Protegido con permiso `ajustar_inventario`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `AjusteListCreateView.post`
  - **Test:** `AjustesInventarioEpica2DTestCase::test_creacion_ajuste_y_actualizacion_lote`

- [x] ✅ **T-209.3**: Actualizar `cantidad_disponible` en lote.
  - **Qué hace:** Dentro de una transacción atómica bloquea la fila del lote, obtiene `cantidad_anterior` y actualiza `cantidad_disponible = cantidad_nueva`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `AjusteListCreateView.post`
  - **Test:** `AjustesInventarioEpica2DTestCase::test_creacion_ajuste_y_actualizacion_lote`

- [x] ✅ **T-209.4**: Validar motivo obligatorio.
  - **Qué hace:** Validador en `AjusteCreateSerializer` que rechaza motivos vacíos o compuestos únicamente por espacios en blanco.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/serializers.py` → `AjusteCreateSerializer`
  - **Test:** `AjustesInventarioEpica2DTestCase::test_rechazo_motivo_vacio_y_cantidad_negativa`

- [x] ✅ **T-209.5**: Bloquear edición directa de stock de lote.
  - **Qué hace:** El campo `cantidad_disponible` está marcado como `read_only_fields` en `LoteSerializer` y `LoteCreateSerializer`, forzando a que cualquier cambio pase por el endpoint atómico de ajustes con auditoría (`AJUSTE_INVENTARIO`).
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/serializers.py` & `views.py`
  - **Test:** `AjustesInventarioEpica2DTestCase::test_permisos_y_auditoria_ajuste`

### Historia de Usuario HU-210: Historial de ajustes separado
- [x] ✅ **T-210.1**: Endpoint `GET /inventario/ajustes`.
  - **Qué hace:** Retorna la lista de ajustes de inventario ordenados por `fecha_hora` descendente, permitiendo filtros por `?lote_id=X` y `?material_id=Y`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `AjusteListCreateView.get`
  - **Test:** `AjustesInventarioEpica2DTestCase::test_historial_ajustes_con_filtros`

- [x] ✅ **T-210.2**: Historial independiente.
  - **Qué hace:** Mantiene una tabla y endpoint dedicados (`AjusteInventario`), separados de salidas y entradas de almacén.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/models_ajustes.py`
  - **Test:** `AjustesInventarioEpica2DTestCase::test_historial_ajustes_con_filtros`

- [x] ✅ **T-210.3**: Inmutabilidad de `AjusteInventario`.
  - **Qué hace:** Sobrescribe `save()` (para instancias existentes) y `delete()` en el modelo `AjusteInventario` para lanzar `ValidationError` si se intenta editar o eliminar un registro.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/models_ajustes.py` → `AjusteInventario`
  - **Test:** `AjustesInventarioEpica2DTestCase::test_inmutabilidad_modelo_ajuste`

- [x] ✅ **T-210.4**: Endpoint Unificado de Movimientos de Material (`GET /inventario/materiales/{id}/movimientos`).
  - **Qué hace:** Agrega un endpoint de trazabilidad integral para materiales que consolida entradas de lotes, salidas FEFO y ajustes manuales en orden cronológico descendente. Soporta además ajuste directo por `material_id` y compatibilidad bidireccional de aliases (`lote`/`lote_id`, `material`/`material_id`, `motivo`/`motivo_destino`).
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` (`MaterialMovimientosListView`, `AjusteListCreateView`), `file:///home/v4/Ceos/Backend/apps/inventario/serializers.py`, `file:///home/v4/Ceos/Backend/apps/inventario/urls.py`
  - **Test:** `AjustesInventarioEpica2DTestCase::test_historial_movimientos_unificado_material`

### 🧪 Test Épica 2.D
- [x] ✅ **T-209.T**: Suite de tests para Épica 2.D.
  - **Qué hace:** Suite de 6 test cases que prueban la creación de ajustes, actualización de stock del lote, soporte de alias y ajuste por material sin lote inicial, validación de motivos obligatorios, inmutabilidad del modelo, bloqueo por permisos, auditoría e historial con filtros y movimientos unificados. 6 tests pasando al 100%.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/tests/test_ajustes.py`
  - **Test:** `AjustesInventarioEpica2DTestCase` (6 tests pasando al 100%)


---

## ÉPICA 2.E — Solicitudes de Material

### Historia de Usuario HU-211: Creación de solicitud
- [x] ✅ **T-211.1**: Modelo `SolicitudMaterial`.
  - **Qué hace:** Modelo ORM con campos `solicitante`, `material`, `cantidad_solicitada`, `motivo`, `estado` (pendiente, aprobada, rechazada, cancelada), `comentario_resolucion`, `resuelto_por`, `fecha_creacion`, `fecha_resolucion`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/models_solicitudes.py`
  - **Test:** `SolicitudesMaterialEpica2ETestCase::test_creacion_solicitud_material`

- [x] ✅ **T-211.2**: Endpoint `POST /inventario/solicitudes`.
  - **Qué hace:** Permite a usuarios con permiso `solicitar_material` (Doctores, Gestores, Admins) crear una solicitud de material en estado pendiente.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `SolicitudListCreateView.post`
  - **Test:** `SolicitudesMaterialEpica2ETestCase::test_creacion_solicitud_material`

- [x] ✅ **T-211.3**: Sugerencia de motivo `sin_stock`.
  - **Qué hace:** Si el motivo se omite o viene en blanco, asigna por defecto `'sin_stock'`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `SolicitudListCreateView.post`
  - **Test:** `SolicitudesMaterialEpica2ETestCase::test_creacion_solicitud_material`

- [x] ✅ **T-211.4**: Estado inicial `pendiente`.
  - **Qué hace:** Toda solicitud recién registrada inicia en estado `pendiente`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/models_solicitudes.py` & `views.py`
  - **Test:** `SolicitudesMaterialEpica2ETestCase::test_creacion_solicitud_material`

- [x] ✅ **T-211.5**: Notificación a roles encargados.
  - **Qué hace:** Envía notificación in-app y mensaje externo a usuarios activos con los permisos `aprobar_solicitud` o `ajustar_inventario`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `SolicitudListCreateView.post`
  - **Test:** `SolicitudesMaterialEpica2ETestCase::test_creacion_solicitud_material`

- [x] ✅ **T-211.6**: Modelo `NotificacionApp`.
  - **Qué hace:** Modelo ORM para notificaciones internas del sistema in-app con campos `usuario`, `titulo`, `mensaje`, `leida`, `tipo`, `referencia_id`, `fecha_creacion`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/notificaciones/models.py`
  - **Test:** `SolicitudesMaterialEpica2ETestCase::test_creacion_solicitud_material`

- [x] ✅ **T-211.7**: Endpoint `GET /notificaciones`.
  - **Qué hace:** Retorna la lista de notificaciones in-app del usuario autenticado con filtrado opcional `?leida=false`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/notificaciones/views.py` → `NotificacionListView`
  - **Test:** `SolicitudesMaterialEpica2ETestCase::test_creacion_solicitud_material`

- [x] ✅ **T-211.8**: Soporte para solicitud de nuevos materiales no catalogados.
  - **Qué hace:** Permite a los solicitantes (como Doctores) pedir materiales que aún no existen en el catálogo maestro, registrando `nombre_material_nuevo`, `area` y `unidad_medida`, enviando notificación a los administradores y gestores de inventario para su evaluación y adquisición.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/models_solicitudes.py`, `file:///home/v4/Ceos/Backend/apps/inventario/serializers.py`, `file:///home/v4/Ceos/Backend/apps/inventario/views.py`
  - **Test:** `SolicitudesMaterialEpica2ETestCase::test_creacion_solicitud_material_nuevo_no_catalogado`

### Historia de Usuario HU-212: Edición/cancelación de solicitud propia
- [x] ✅ **T-212.1**: Endpoint `PATCH /inventario/solicitudes/{id}`.
  - **Qué hace:** Permite modificar `cantidad_solicitada` y `motivo` de una solicitud propia en estado pendiente.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `SolicitudDetailView.patch`
  - **Test:** `SolicitudesMaterialEpica2ETestCase::test_edicion_y_cancelacion_solicitud_propia`

- [x] ✅ **T-212.2**: Validar dueño y estado pendiente.
  - **Qué hace:** Retorna 403 Forbidden si la solicitud pertenece a otro usuario y 400 Bad Request si el estado no es `pendiente`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `SolicitudDetailView.patch`
  - **Test:** `SolicitudesMaterialEpica2ETestCase::test_edicion_y_cancelacion_solicitud_propia`

- [x] ✅ **T-212.3**: Endpoint `POST /inventario/solicitudes/{id}/cancelar`.
  - **Qué hace:** Cambia el estado de la solicitud propia a `cancelada` si se encuentra en estado `pendiente`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `SolicitudCancelarView.post`
  - **Test:** `SolicitudesMaterialEpica2ETestCase::test_edicion_y_cancelacion_solicitud_propia`

- [x] ✅ **T-212.4**: Auditoría de cambios.
  - **Qué hace:** Registra `EDICION_SOLICITUD_MATERIAL` y `CANCELACION_SOLICITUD_MATERIAL` en la bitácora de auditoría.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py`
  - **Test:** `SolicitudesMaterialEpica2ETestCase::test_edicion_y_cancelacion_solicitud_propia`

### Historia de Usuario HU-213: Resolución de solicitudes (GestorInventario)
- [x] ✅ **T-213.1**: Endpoint `GET /inventario/solicitudes?estado=pendiente`.
  - **Qué hace:** Gestores y Administradores pueden listar todas las solicitudes pendientes del sistema.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `SolicitudListCreateView.get`
  - **Test:** `SolicitudesMaterialEpica2ETestCase::test_vista_global_y_filtros`

- [x] ✅ **T-213.2**: Endpoint `POST /inventario/solicitudes/{id}/resolver`.
  - **Qué hace:** Permite a usuarios con permiso `aprobar_solicitud` aprobar o rechazar solicitudes pendientes.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `SolicitudResolverView.post`
  - **Test:** `SolicitudesMaterialEpica2ETestCase::test_resolucion_solicitud_aprobada_y_notificacion`

- [x] ✅ **T-213.3**: Comentario obligatorio en rechazo.
  - **Qué hace:** `SolicitudResolverSerializer` valida que el comentario no esté vacío cuando `accion == 'rechazar'`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/serializers.py` → `SolicitudResolverSerializer`
  - **Test:** `SolicitudesMaterialEpica2ETestCase::test_resolucion_solicitud_rechazada_comentario_obligatorio`

- [x] ✅ **T-213.4**: Confirmación de no alteración de stock al aprobar.
  - **Qué hace:** Garantiza que al aprobar una solicitud, las existencias del inventario no sufran cambios automáticos, posponiendo el descuento a la entrega/salida FEFO.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `SolicitudResolverView.post`
  - **Test:** `SolicitudesMaterialEpica2ETestCase::test_resolucion_solicitud_aprobada_y_notificacion`

- [x] ✅ **T-213.5**: Notificación al solicitante.
  - **Qué hace:** Crea registro en `NotificacionApp` y envía mensaje externo al solicitante con el resultado de la resolución.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `SolicitudResolverView.post`
  - **Test:** `SolicitudesMaterialEpica2ETestCase::test_resolucion_solicitud_aprobada_y_notificacion`

- [x] ✅ **T-213.6**: Auditoría de resolución.
  - **Qué hace:** Registra `RESOLUCION_SOLICITUD_MATERIAL` en auditoría.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `SolicitudResolverView.post`
  - **Test:** `SolicitudesMaterialEpica2ETestCase::test_resolucion_solicitud_aprobada_y_notificacion`

### Historia de Usuario HU-214: Vista global de solicitudes (Administrador)
- [x] ✅ **T-214.1**: Endpoint `GET /inventario/solicitudes`.
  - **Qué hace:** Permite consultar todas las solicitudes a administradores/gestores, manteniendo a usuarios comunes solo sus propias solicitudes.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `SolicitudListCreateView.get`
  - **Test:** `SolicitudesMaterialEpica2ETestCase::test_vista_global_y_filtros`

- [x] ✅ **T-214.2**: Filtros de consulta.
  - **Qué hace:** Permite filtrar solicitudes por `?estado=`, `?material_id=`, y `?solicitante_id=`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `SolicitudListCreateView.get`
  - **Test:** `SolicitudesMaterialEpica2ETestCase::test_vista_global_y_filtros`

- [x] ✅ **T-214.3**: Solo lectura.
  - **Qué hace:** La consulta global expone las solicitudes sin permitir mutaciones desde el listado.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `SolicitudListCreateView.get`
  - **Test:** `SolicitudesMaterialEpica2ETestCase::test_vista_global_y_filtros`

### 🧪 Test Épica 2.E
- [x] ✅ **T-211.T**: Suite de tests para Épica 2.E.
  - **Qué hace:** Suite de 5 test cases que comprueban la creación, edicion, cancelación, resolución (aprobación/rechazo), inmutabilidad de stock al aprobar, notificaciones in-app y externas, auditoría y vista global con filtros. 5 tests pasando al 100%.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/tests/test_solicitudes.py`
  - **Test:** `SolicitudesMaterialEpica2ETestCase` (5 tests pasando al 100%)

---

## ÉPICA 2.F — Alertas de Stock Bajo y Vencimiento

### Historia de Usuario HU-215: Revisión periódica y envío de alertas
- [x] ✅ **T-215.1**: Tarea de Celery `revisar_alertas_inventario`.
  - **Qué hace:** Tarea periódica `@shared_task` que escanea de forma automatizada o síncrona los materiales y lotes para emitir alertas de stock y caducidad.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/tasks.py` → `revisar_alertas_inventario`
  - **Test:** `AlertasInventarioEpica2FTestCase::test_ejecucion_revisar_alertas_envia_notificaciones`

- [x] ✅ **T-215.2**: Función `materiales_bajo_minimo()`.
  - **Qué hace:** Retorna la lista de materiales activos cuyo stock total disponible acumulado por lotes es menor o igual al `stock_minimo`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/tasks.py` → `materiales_bajo_minimo`
  - **Test:** `AlertasInventarioEpica2FTestCase::test_materiales_bajo_minimo_y_lotes_vencimiento_helpers`

- [x] ✅ **T-215.3**: Función `lotes_con_alerta_vencimiento_activa()`.
  - **Qué hace:** Retorna lotes con existencias disponibles que presentan caducidad dentro del umbral de alerta (o <= 30 días) o se encuentran vencidos.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/tasks.py` → `lotes_con_alerta_vencimiento_activa`
  - **Test:** `AlertasInventarioEpica2FTestCase::test_materiales_bajo_minimo_y_lotes_vencimiento_helpers`

- [x] ✅ **T-215.4**: Envío agrupado vía `NotificationService`.
  - **Qué hace:** Notifica a administradores y gestores activos vía mensajería externa (Telegram/WhatsApp).
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/tasks.py` → `revisar_alertas_inventario`
  - **Test:** `AlertasInventarioEpica2FTestCase::test_ejecucion_revisar_alertas_envia_notificaciones`

- [x] ✅ **T-215.5**: Registros en `NotificacionApp`.
  - **Qué hace:** Crea notificaciones in-app para cada gestor y administrador activo ante alertas de stock bajo o vencimiento.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/tasks.py` → `revisar_alertas_inventario`
  - **Test:** `AlertasInventarioEpica2FTestCase::test_ejecucion_revisar_alertas_envia_notificaciones`

- [x] ✅ **T-215.6**: Evitar duplicados el mismo día.
  - **Qué hace:** Verifica que no exista una `NotificacionApp` del mismo tipo y `referencia_id` registrada en la fecha actual (`fecha_creacion__date=hoy`) antes de reemitir alertas.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/tasks.py` → `revisar_alertas_inventario`
  - **Test:** `AlertasInventarioEpica2FTestCase::test_evitar_notificaciones_duplicadas_mismo_dia`

### Historia de Usuario HU-216: Toggle de alertas de inventario
- [x] ✅ **T-216.1**: Campo `alertas_inventario_activas` en `ConfiguracionSistema`.
  - **Qué hace:** Switch booleano global en BD y caché de 24h para activar/desactivar el job de alertas.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/notificaciones/models.py` → `ConfiguracionSistema`
  - **Test:** `AlertasInventarioEpica2FTestCase::test_toggle_alertas_desactivadas`

- [x] ✅ **T-216.2**: Endpoint `PATCH /admin/config/alertas-inventario`.
  - **Qué hace:** Endpoint restringido a Administradores para alternar `alertas_inventario_activas` en tiempo de ejecución.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/notificaciones/views.py` → `ConfiguracionAlertasInventarioView`
  - **Test:** `AlertasInventarioEpica2FTestCase::test_endpoint_toggle_alertas_inventario`

- [x] ✅ **T-216.3**: Respetar toggle en tareas Celery.
  - **Qué hace:** `revisar_alertas_inventario` omite el envío de notificaciones in-app y externas si el toggle está desactivado (`False`).
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/tasks.py` → `revisar_alertas_inventario`
  - **Test:** `AlertasInventarioEpica2FTestCase::test_toggle_alertas_desactivadas`

- [x] ✅ **T-216.4**: Mantenimiento de cálculos para dashboards.
  - **Qué hace:** Las funciones helper `materiales_bajo_minimo()` y `lotes_con_alerta_vencimiento_activa()` permiten seguir alimentando los dashboards de stock sin depender del envío de notificaciones.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/tasks.py`
  - **Test:** `AlertasInventarioEpica2FTestCase::test_materiales_bajo_minimo_y_lotes_vencimiento_helpers`

### 🧪 Test Épica 2.F
- [x] ✅ **T-215.T**: Suite de tests para Épica 2.F.
  - **Qué hace:** Suite de 5 test cases que comprueban detección de stock bajo, lotes próximos a vencer, emisión de notificaciones in-app y externas, no duplicidad el mismo día, toggle global y endpoint de configuración. 5 tests pasando al 100%.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/tests/test_alertas.py`
  - **Test:** `AlertasInventarioEpica2FTestCase` (5 tests pasando al 100%)

---

## ÉPICA 2.G — Reportes en PDF (bajo demanda)

### Historia de Usuario HU-217: Generación de PDF por fecha o rango
- [x] ✅ **T-217.1**: Endpoint `POST /inventario/reportes/pdf`.
  - **Qué hace:** Endpoint HTTP POST que recibe filtros por rango de fechas, área, categoría y usuario para solicitar la generación de un documento PDF de reporte de inventario.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views_reportes.py` → `ReportePDFView`
  - **Test:** `ReportesPDFEpica2GTestCase::test_generar_pdf_reporte_inventario_por_rango_fechas`

- [x] ✅ **T-217.2**: Función de agregación de datos para el reporte.
  - **Qué hace:** Recopila y agrupa ingresos de lotes, salidas FEFO, ajustes de existencias y solicitudes de material dentro del rango temporal y filtros aplicados.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/services_reportes.py` → `obtener_datos_reporte_inventario`
  - **Test:** `ReportesPDFEpica2GTestCase::test_generar_pdf_reporte_inventario_por_rango_fechas`

- [x] ✅ **T-217.3**: Generar PDF con WeasyPrint.
  - **Qué hace:** Renderiza la plantilla HTML `inventario_reporte.html` con estilos CSS institucionales y convierte el HTML a un buffer binario PDF usando WeasyPrint.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/services_reportes.py` → `generar_pdf_reporte_inventario`
  - **Test:** `ReportesPDFEpica2GTestCase::test_generar_pdf_reporte_inventario_por_rango_fechas`

- [x] ✅ **T-217.4**: Retornar URL o archivo descargable.
  - **Qué hace:** Devuelve `HttpResponse(pdf_bytes, content_type='application/pdf')` con cabecera `Content-Disposition: attachment; filename="reporte_inventario_...pdf"`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views_reportes.py` → `ReportePDFView`
  - **Test:** `ReportesPDFEpica2GTestCase::test_generar_pdf_reporte_inventario_por_rango_fechas`

- [x] ✅ **T-217.5**: Auditoría de generación.
  - **Qué hace:** Registra automáticamente la acción `GENERACION_REPORTE_PDF` en `RegistroAuditoria` con los parámetros solicitados.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views_reportes.py` → `ReportePDFView`
  - **Test:** `ReportesPDFEpica2GTestCase::test_auditoria_generacion_reporte`

### Historia de Usuario HU-218: Filtro de PDF por usuario específico
- [x] ✅ **T-218.1**: Parámetro `usuario_id` en endpoint PDF.
  - **Qué hace:** Permite especificar un ID de usuario objetivo en la solicitud del reporte PDF.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views_reportes.py` → `ReportePDFView`
  - **Test:** `ReportesPDFEpica2GTestCase::test_reporte_filtrado_por_usuario_especifico`

- [x] ✅ **T-218.2**: Filtrar actividad del usuario.
  - **Qué hace:** Restringe los lotes ingresados, movimientos de salida, ajustes de existencias y solicitudes a los correspondientes al usuario seleccionado.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/services_reportes.py` → `obtener_datos_reporte_inventario`
  - **Test:** `ReportesPDFEpica2GTestCase::test_reporte_filtrado_por_usuario_especifico`

- [x] ✅ **T-218.3**: Encabezado personalizado en PDF.
  - **Qué hace:** Personaliza el título del documento ("Reporte de Actividad de Inventario — Usuario: [Nombre]") y los metadatos visuales del PDF.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/templates/reportes/inventario_reporte.html`
  - **Test:** `ReportesPDFEpica2GTestCase::test_reporte_filtrado_por_usuario_especifico`

### Historia de Usuario HU-219: Entrega dual (descarga + mensajería)
- [x] ✅ **T-219.1**: Descarga directa inmediata.
  - **Qué hace:** Emisión inmediata del archivo PDF como respuesta HTTP stream/attachment al cliente.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views_reportes.py` → `ReportePDFView`
  - **Test:** `ReportesPDFEpica2GTestCase::test_generar_pdf_reporte_inventario_por_rango_fechas`

- [x] ✅ **T-219.2**: Endpoint `POST /inventario/reportes/enviar-por-mensajeria`.
  - **Qué hace:** Genera el reporte y despacha un resumen ejecutivo detallado vía `NotificationService` por Telegram / WhatsApp.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views_reportes.py` → `ReporteEnviarMensajeriaView`
  - **Test:** `ReportesPDFEpica2GTestCase::test_endpoint_enviar_reporte_por_mensajeria_directo`

- [x] ✅ **T-219.3**: Archivo idéntico en ambos canales.
  - **Qué hace:** Garantiza la consistencia de los datos agregados tanto en la versión descargable PDF como en la síntesis enviada por mensajería.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/services_reportes.py`
  - **Test:** `ReportesPDFEpica2GTestCase::test_entrega_dual_descarga_y_mensajeria`

### 🧪 Test Épica 2.G
- [x] ✅ **T-217.T**: Suite de tests para Épica 2.G.
  - **Qué hace:** Suite de 5 test cases que verifican la generación de PDF, filtrado por usuario, entrega dual por mensajería, endpoint dedicado y auditoría.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/tests/test_reportes.py`
  - **Test:** `ReportesPDFEpica2GTestCase` (5 tests passing al 100%)

---

## ÉPICA 2.H — Dashboard y Reporte de Gastos

### Historia de Usuario HU-220: Dashboard de materiales más usados
- [x] ✅ **T-220.1**: Endpoint `GET /inventario/dashboard/mas-usados`.
  - **Qué hace:** Endpoint HTTP GET que expone el ranking de materiales con mayor volumen de consumo registrado en movimientos de salida.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views_dashboard.py` → `MaterialesMasUsadosView`
  - **Test:** `DashboardYGastosEpica2HTestCase::test_materiales_mas_usados_ranking`

- [x] ✅ **T-220.2**: Parámetros de rango de fechas y áreas/categorías.
  - **Qué hace:** Filtra los consumos acumulados por `fecha_inicio`, `fecha_fin`, `area_id`, `categoria_id` y `limit`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views_dashboard.py` → `MaterialesMasUsadosView`
  - **Test:** `DashboardYGastosEpica2HTestCase::test_materiales_mas_usados_con_filtros`

- [x] ✅ **T-220.3**: Agregación por `SUM(cantidad)`.
  - **Qué hace:** Ejecuta consulta agregada con `.annotate(total_usado=Sum('cantidad_total'))` sobre `MovimientoSalida`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views_dashboard.py`
  - **Test:** `DashboardYGastosEpica2HTestCase::test_materiales_mas_usados_ranking`

### Historia de Usuario HU-221: Panel de materiales con solicitud preventiva
- [x] ✅ **T-221.1**: Endpoint `GET /inventario/dashboard/reposicion-preventiva`.
  - **Qué hace:** Endpoint HTTP GET que expone la nómina de materiales con solicitudes de reabastecimiento por motivos preventivos.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views_dashboard.py` → `ReposicionPreventivaView`
  - **Test:** `DashboardYGastosEpica2HTestCase::test_reposicion_preventiva`

- [x] ✅ **T-221.2**: Agregación por motivo `reposicion_preventiva`.
  - **Qué hace:** Agrupa solicitudes con `motivo__icontains='reposicion_preventiva'`, contabilizando solicitudes y total de unidades requeridas.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views_dashboard.py`
  - **Test:** `DashboardYGastosEpica2HTestCase::test_reposicion_preventiva`

- [x] ✅ **T-221.3**: Consulta independiente.
  - **Qué hace:** Proporciona un servicio REST independiente optimizado para alimentar widgets de dashboards analíticos.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views_dashboard.py`
  - **Test:** `DashboardYGastosEpica2HTestCase::test_reposicion_preventiva`

### Historia de Usuario HU-222: Reporte de gastos agrupado
- [x] ✅ **T-222.1**: Endpoint `GET /inventario/reportes/gastos`.
  - **Qué hace:** Endpoint HTTP GET que calcula y consolida los costos financieros de lotes ingresados en el período especificado.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views_dashboard.py` → `ReporteGastosView`
  - **Test:** `DashboardYGastosEpica2HTestCase::test_reporte_gastos_agrupado_y_porcentaje_incompleto`

- [x] ✅ **T-222.2**: Agregación de gastos por categoría.
  - **Qué hace:** Agrupa el costo monetario total de lotes (`SUM(costo)`) por categoría de material.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views_dashboard.py`
  - **Test:** `DashboardYGastosEpica2HTestCase::test_reporte_gastos_agrupado_y_porcentaje_incompleto`

- [x] ✅ **T-222.3**: Agregación de gastos por material.
  - **Qué hace:** Agrupa el costo monetario total de lotes (`SUM(costo)`) por cada material individual.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views_dashboard.py`
  - **Test:** `DashboardYGastosEpica2HTestCase::test_reporte_gastos_agrupado_y_porcentaje_incompleto`

- [x] ✅ **T-222.4**: Porcentaje global de costo incompleto.
  - **Qué hace:** Determina la proporción de lotes sin costo monetario asignado (`(lotes_sin_costo / total_lotes) * 100`) para alertar sobre vacíos de registro.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views_dashboard.py`
  - **Test:** `DashboardYGastosEpica2HTestCase::test_reporte_gastos_agrupado_y_porcentaje_incompleto`

### 🧪 Test Épica 2.H
- [x] ✅ **T-220.T**: Suite de tests para Épica 2.H.
  - **Qué hace:** Suite de 4 test cases automatizados que certifican el funcionamiento del ranking de consumo, filtrado, reposición preventiva y agregaciones financieras de gastos.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/tests/test_dashboard.py`
  - **Test:** `DashboardYGastosEpica2HTestCase` (4 tests passing al 100%)

---

# Módulo 3: Respaldo de Base de Datos

## ÉPICA 3.A — Backup Automático y Manual vía Telegram

### Historia de Usuario HU-301: Backup automático diario
- [x] ✅ **T-301.1**: Tarea de Celery `generar_backup_diario`.
  - **Qué hace:** Tarea de Celery Beat programada para disparar automáticamente el proceso diario de respaldo.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/backup/tasks.py` → `generar_backup_diario`
  - **Test:** `BackupEpica3ATestCase::test_ejecutar_backup_servicio_automatico`

- [x] ✅ **T-301.2**: Generación del dump (`pg_dump`) comprimido (`gzip`).
  - **Qué hace:** Ejecuta `pg_dump` (o volcado directo en SQLite) y comprime el resultado al vuelo en formato `gzip`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/backup/services.py` → `ejecutar_backup`
  - **Test:** `BackupEpica3ATestCase::test_ejecutar_backup_servicio_automatico`

- [x] ✅ **T-301.3**: Nomenclatura `backup_ceos_YYYY-MM-DD.sql.gz`.
  - **Qué hace:** Asigna nombres estandarizados basados en la fecha y hora de ejecución (`backup_ceos_YYYY-MM-DD_HHMMSS.sql.gz`).
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/backup/services.py`
  - **Test:** `BackupEpica3ATestCase::test_ejecutar_backup_servicio_automatico`

- [x] ✅ **T-301.4**: Envío vía `NotificationService` al Superadmin.
  - **Qué hace:** Transmite la notificación detallada del respaldo por Telegram/WhatsApp a los usuarios con rol SUPERADMIN.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/backup/services.py`
  - **Test:** `BackupEpica3ATestCase::test_ejecutar_backup_servicio_automatico`

- [x] ✅ **T-301.5**: Borrado del servidor tras confirmación de envío.
  - **Qué hace:** Elimina el archivo comprimido temporal del disco servidor tras despachar las notificaciones para proteger la privacidad y optimizar espacio.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/backup/services.py`
  - **Test:** `BackupEpica3ATestCase::test_ejecutar_backup_servicio_automatico`

- [x] ✅ **T-301.6**: Lógica de reintentos ante fallos de envío.
  - **Qué hace:** Maneja excepciones y capturas de error durante la transmisión de mensajes con notificaciones individuales por destinatario.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/backup/services.py`
  - **Test:** `BackupEpica3ATestCase::test_ejecutar_backup_servicio_automatico`

- [x] ✅ **T-301.7**: Modelo `RegistroBackup`.
  - **Qué hace:** Almacena la auditoría persistente de cada intento de respaldo (fecha, tamaño, estado exitoso/fallido, origen y usuario).
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/backup/models.py` → `RegistroBackup`
  - **Test:** `BackupEpica3ATestCase::test_generar_backup_manual_endpoint`

- [x] ✅ **T-301.8**: Manejo de errores irrecuperables.
  - **Qué hace:** Ante fallos de dump o sistema, graba `exitoso=False` con el traceback en `detalles_error` y envía una alerta crítica de fallo al Superadmin.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/backup/services.py`
  - **Test:** `BackupEpica3ATestCase::test_ejecutar_backup_servicio_automatico`

### Historia de Usuario HU-302: Backup manual bajo demanda
- [x] ✅ **T-302.1**: Endpoint `POST /admin/backup/generar` restringido a Superadmin.
  - **Qué hace:** Endpoint HTTP POST que requiere permisos `EsSuperadmin` para disparar respaldos manuales.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/backup/views.py` → `BackupGenerarView`
  - **Test:** `BackupEpica3ATestCase::test_generar_backup_manual_endpoint` & `test_generar_backup_restringido_a_superadmin`

- [x] ✅ **T-302.2**: Función reutilizable `ejecutar_backup(origen)`.
  - **Qué hace:** Núcleo de lógica centralizado que atiende tanto respaldos automáticos como manuales.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/backup/services.py`
  - **Test:** `BackupEpica3ATestCase::test_generar_backup_manual_endpoint`

- [x] ✅ **T-302.3**: Campo `origen` en `RegistroBackup`.
  - **Qué hace:** Distingue si el origen fue `AUTOMATICO` o `MANUAL`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/backup/models.py`
  - **Test:** `BackupEpica3ATestCase::test_generar_backup_manual_endpoint`

- [x] ✅ **T-302.4**: Ejecución asíncrona vía Celery.
  - **Qué hace:** Tarea `generar_backup_manual_task` para ejecuciones en segundo plano cuando se solicita `async=True`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/backup/tasks.py`
  - **Test:** `BackupEpica3ATestCase::test_generar_backup_manual_endpoint`

- [x] ✅ **T-302.5**: Endpoint `GET /admin/backup/estado/{tarea_id}`.
  - **Qué hace:** Permite consultar el progreso y resultado de una tarea o registro de respaldo por su ID.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/backup/views.py` → `BackupEstadoView`
  - **Test:** `BackupEpica3ATestCase::test_consultar_estado_backup`

### Historia de Usuario HU-303: Historial de backups
- [x] ✅ **T-303.1**: Endpoint `GET /admin/backup/historial`.
  - **Qué hace:** Retorna la bitácora completa de respaldos registrados en el sistema para control del Superadmin.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/backup/views.py` → `BackupHistorialView`
  - **Test:** `BackupEpica3ATestCase::test_historial_backups_con_filtros`

- [x] ✅ **T-303.2**: Paginación y filtros del historial.
  - **Qué hace:** Permite filtrar por `origen`, `exitoso` y controlar la paginación (`page`, `page_size`).
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/backup/views.py` → `BackupHistorialView`
  - **Test:** `BackupEpica3ATestCase::test_historial_backups_con_filtros`

### 🧪 Test Épica 3.A
- [x] ✅ **T-301.T**: Suite de tests para Épica 3.A.
  - **Qué hace:** Suite de 5 test cases automatizados que verifican la generación de respaldos manuales y automáticos, restricciones de seguridad de Superadmin, remoción de archivos temporales y consulta de historial.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/backup/tests.py`
  - **Test:** `BackupEpica3ATestCase` (5 tests passing al 100%)

---

# Módulo 4: Actualizaciones y Ajustes del Sistema

## Ajuste 4.A — Íconos para Catálogo de Áreas y Categorías (Extensión)

### Historia de Usuario HU-304: Asignación de íconos visuales a Áreas y Categorías
- [x] ✅ **T-304.1**: Agregar campo `icono` (`CharField`, `max_length=50`, default `"package"`) al modelo `Area`.
  - **Qué hace:** Incorpora el campo `icono` en la entidad `Area` para almacenar el identificador de ícono Phosphor con fallback automático a `'package'`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/models.py`
  - **Test:** `IconosCatalogoEpica4ATestCase::test_t304_1_y_3_area_campo_icono_y_fallback`

- [x] ✅ **T-304.2**: Agregar campo `icono` (`CharField`, `max_length=50`, default `"package"`) al modelo `CategoriaMaterial`.
  - **Qué hace:** Incorpora el campo `icono` en la entidad `CategoriaMaterial` para almacenar el identificador de ícono Phosphor con fallback automático a `'package'`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/models.py`
  - **Test:** `IconosCatalogoEpica4ATestCase::test_t304_2_y_3_categoria_campo_icono_y_fallback`

- [x] ✅ **T-304.3**: Generar y aplicar migración de Django (`makemigrations` + `migrate`).
  - **Qué hace:** Genera y ejecuta la migración `0002_area_icono_categoriamaterial_icono.py`, asegurando que tanto tablas nuevas como registros preexistentes mantengan el valor default `'package'` sin intervención manual.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/migrations/0002_area_icono_categoriamaterial_icono.py`
  - **Test:** `IconosCatalogoEpica4ATestCase::test_t304_3_migracion_registros_preexistentes`

- [x] ✅ **T-304.4**: Crear catálogo de íconos válidos en backend.
  - **Qué hace:** Define la lista `ICONOS_DISPONIBLES`, el conjunto `ICONOS_DISPONIBLES_SET` y la función `es_icono_valido(identificador)` alineados con la biblioteca `phosphor_flutter` de la app móvil.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/constants.py`
  - **Test:** `IconosCatalogoEpica4ATestCase::test_t304_4_catalogo_iconos_validos`

- [x] ✅ **T-304.5**: Endpoint `GET /inventario/iconos-disponibles`.
  - **Qué hace:** Expone el catálogo de íconos permitidos mediante un endpoint REST autenticado que devuelve la lista y total de íconos disponibles.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py` → `IconosDisponiblesView`, `file:///home/v4/Ceos/Backend/apps/inventario/urls.py`
  - **Test:** `IconosCatalogoEpica4ATestCase::test_t304_5_endpoint_iconos_disponibles`

- [x] ✅ **T-304.6**: Actualizar serializers de `Area` y `CategoriaMaterial` (lectura y escritura).
  - **Qué hace:** Adapta `AreaSerializer`, `AreaCreateUpdateSerializer`, `CategoriaMaterialSerializer` y `CategoriaMaterialCreateUpdateSerializer` para serializar el campo `icono` y asignar el fallback `'package'` por defecto.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/serializers.py`
  - **Test:** `IconosCatalogoEpica4ATestCase::test_t304_6_serializers_area_y_categoria`

- [x] ✅ **T-304.7**: Agregar validación en endpoints `POST`/`PATCH` de `/inventario/areas` y `/inventario/categorias`.
  - **Qué hace:** Valida en `AreaCreateUpdateSerializer` y `CategoriaMaterialCreateUpdateSerializer` que cualquier ícono suministrado pertenezca al catálogo permitido, rechazando con código HTTP 400 y mensaje descriptivo si no es válido.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/serializers.py`, `file:///home/v4/Ceos/Backend/apps/inventario/views.py`
  - **Test:** `IconosCatalogoEpica4ATestCase::test_t304_7_rechazo_iconos_invalidos_post_y_patch`

- [x] ✅ **T-304.8**: Actualizar documentación OpenAPI/Swagger de los endpoints.
  - **Qué hace:** Documenta formalmente en docstrings y serializers el nuevo campo `icono` para creación, consulta y edición de áreas y categorías, así como el endpoint del catálogo de íconos disponibles.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py`
  - **Test:** `IconosCatalogoEpica4ATestCase::test_t304_5_endpoint_iconos_disponibles`

### 🧪 Test Ajuste 4.A
- [x] ✅ **T-304.T**: Suite de tests para Ajuste 4.A.
  - **Qué hace:** Suite automatizada de 8 test cases que certifica la creación con/sin ícono, edición, rechazo ante íconos inválidos, migración no nula y disponibilidad del catálogo de íconos.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/tests/test_catalogo_materiales.py`
  - **Test:** `IconosCatalogoEpica4ATestCase` (8 tests passing al 100%)

---

## Ajuste 4.B — Inicialización de Roles, Permisos y Superusuario desde .env

### Tareas de Ajuste Backend:
- [x] ✅ **T-AJUSTE-BK.1**: Comando de gestión `init_superuser` para inicialización de roles, permisos y credenciales desde `.env`.
  - **Qué hace:** Crea el comando `python manage.py init_superuser` que ejecuta automáticamente la carga de seeds (`cargar_seeds_roles_y_permisos()`), lee las variables de entorno `DJANGO_SUPERUSER_USERNAME`, `DJANGO_SUPERUSER_EMAIL` y `DJANGO_SUPERUSER_PASSWORD`, y genera o actualiza al superusuario con rol Superadmin.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/management/commands/init_superuser.py`
  - **Test:** Ejecución exitosa de `python manage.py init_superuser` y verificación de login HTTP 200 en `POST /api/auth/login`.

- [x] ✅ **T-AJUSTE-BK.2**: Automatización completa de migración y arranque en `setup_db.py`.
  - **Qué hace:** Refactoriza el script `setup_db.py` para ejecutar de manera orquestada `makemigrations`, `migrate` e `init_superuser`, dejando la base de datos completamente lista para pruebas con un solo comando.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/setup_db.py`
  - **Test:** Ejecución completa sin errores de `python setup_db.py`.

- [x] ✅ **T-AJUSTE-BK.3**: Actualización de plantillas de configuración de entorno `.env` y `.env.example`.
  - **Qué hace:** Documenta y configura las claves `DJANGO_SUPERUSER_USERNAME`, `DJANGO_SUPERUSER_EMAIL` y `DJANGO_SUPERUSER_PASSWORD` para configuración local personalizable.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/.env`, `file:///home/v4/Ceos/Backend/.env.example`
  - **Test:** Lectura dinámica en `init_superuser.py` y validación de credenciales.

- [x] ✅ **T-AJUSTE-BK.4**: Corrección de importación de submódulos en modelo `inventario` para evitar referencias circulares y asegurar migración íntegra.
  - **Qué hace:** Re-exporta los submódulos `models_lotes`, `models_movimientos`, `models_ajustes` y `models_solicitudes` al final de `apps/inventario/models.py`, permitiendo el autodescubrimiento por Django `makemigrations` sin romper la inicialización por import circular.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/models.py`
  - **Test:** Ejecución de `makemigrations` y suite de tests pasando al 100% (79/79 tests OK).

---

## Ajuste 4.C — Flexibilidad de Primer Login y Normalización Telefónica de Bolivia (+591)

### Historia de Usuario HU-AJUSTE-BK-01: Simplificación de cambio de contraseña en Primer Login
> **Como** usuario nuevo autenticado en su primer inicio de sesión,  
> **Quiero** establecer mi nueva contraseña sin tener que reingresar la contraseña temporal previa,  
> **Para** completar el Paso 1 de forma ágil y sin discrepancias entre el formulario móvil y el backend.

- [x] ✅ **T-AJUSTE-BK.5**: `PrimerLoginCambiarPasswordView` con `password_actual` opcional.
  - **Qué hace:** Modifica el endpoint `POST /api/auth/primer-login/cambiar-password` para que `password_actual` sea opcional, validando directamente `password_nueva` sobre la sesión autenticada del usuario y verificando que cumpla los requisitos de seguridad.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** `test_gestion_cuentas.py::test_t109_flujo_primer_login_y_middleware_bloqueo`

### Historia de Usuario HU-AJUSTE-BK-02: Normalización y validación de números telefónicos de Bolivia
> **Como** administrador o usuario registrando su número de contacto,  
> **Quiero** que el backend valide y normalice automáticamente números de 8 dígitos de Bolivia (+591),  
> **Para** garantizar que los códigos OTP y alertas lleguen a números válidos y existentes de las operadoras bolivianas.

- [x] ✅ **T-AJUSTE-BK.6**: Validador y normalizador de teléfonos de Bolivia `validar_y_normalizar_telefono_bolivia`.
  - **Qué hace:** Implementa función de validación que acepta 8 dígitos numéricos (celulares que inician en 6 o 7, o fijos en 2, 3, 4) con o sin prefijo '591' / '+591', normalizando a `+591XXXXXXXX` y rechazando números de otros países o longitudes inválidas.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/serializers.py`
  - **Test:** Validación integrada en `UsuarioAdminCreateSerializer` y `UsuarioAdminUpdateSerializer`.

- [x] ✅ **T-AJUSTE-BK.7**: Compatibilidad de parámetros en envío y confirmación de OTP telefónico.
  - **Qué hace:** En `PrimerLoginEnviarOtpView`, permite recibir el teléfono en el payload y normalizarlo en el momento; en `PrimerLoginConfirmarOtpView`, acepta indistintamente los nombres de parámetro `otp` o `codigo`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** Suite `apps.usuarios` (17 tests) y suite global de backend (79/79 tests OK).

---

## Ajuste 4.D — Configuración del Bot Telegram @Ceos_Clibot y Polling para Desarrollo Local

### Historia de Usuario HU-AJUSTE-BK-03: Configuración del bot oficial de Telegram
> **Como** usuario del sistema CEOS,  
> **Quiero** recibir notificaciones y vincular mi cuenta desde el bot oficial `@Ceos_Clibot`,  
> **Para** que la identidad del bot coincida con el nombre del sistema CEOS y genere confianza.

- [x] ✅ **T-AJUSTE-BK.8**: Actualización del nombre y usuario del bot de Telegram a `Ceos_Clibot`.
  - **Qué hace:** Cambia la variable `TELEGRAM_BOT_NAME=Ceos_Clibot` en `.env` y `.env.example`, actualiza el valor por defecto en `settings.py`, corrige `PrimerLoginVincularTelegramView` para retornar `bot_username=Ceos_Clibot` en la respuesta, y corrige `obtener_deep_link_telegram` en `services.py` para usar el nombre correcto.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/.env`, `file:///home/v4/Ceos/Backend/config/settings.py`, `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`, `file:///home/v4/Ceos/Backend/apps/notificaciones/services.py`
  - **Test:** Verificación manual del `deep_link` generado: `https://t.me/Ceos_Clibot?start=<TOKEN>`.

### Historia de Usuario HU-AJUSTE-BK-04: Vinculación de Telegram en entorno de desarrollo local (sin webhook)
> **Como** desarrollador probando el sistema en local,  
> **Quiero** poder vincular cuentas de usuario a Telegram sin necesidad de un webhook público,  
> **Para** validar el flujo completo de primer login sin infraestructura de producción.

- [x] ✅ **T-AJUSTE-BK.9**: Endpoint `POST /api/telegram/procesar-updates` (polling manual de mensajes Telegram).
  - **Qué hace:** Implementa `TelegramProcesarUpdatesView` y la función auxiliar `_procesar_telegram_updates()` que consulta `getUpdates` directamente a la API de Telegram, procesa mensajes `/start TOKEN` pendientes, actualiza `telegram_chat_id`, `telegram_vinculado=True` y limpia el token de vinculación. Marca los updates como procesados enviando el `offset = last_id + 1`. Disponible para usuarios autenticados.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`, `file:///home/v4/Ceos/Backend/apps/usuarios/urls.py`
  - **Test:** Respuesta HTTP 200 con `{"vinculados": N, "ignorados": M, "updates_procesados": X}`. Suite global 79/79 OK.

- [x] ✅ **T-AJUSTE-BK.10**: Agregar `/api/telegram/procesar-updates` a la lista de rutas permitidas del middleware de primer login.
  - **Qué hace:** Incluye la ruta en `rutas_permitidas` del `PrimerLoginMiddleware` para que el endpoint sea accesible durante el flujo de primer login (antes de completarlo).
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/middleware.py`
  - **Test:** Endpoint accesible con JWT válido independientemente del estado `primer_login_completado`.

- [x] ✅ **T-AJUSTE-BK.11**: Resiliencia y fallback flexible en el procesamiento de updates de Telegram.
  - **Qué hace:** En `_procesar_telegram_updates()`, permite vincular la cuenta tanto si el mensaje contiene `/start TOKEN` como si el usuario escribió simplemente `/start`, `/star` o cualquier mensaje directo al bot, asociándolo automáticamente con el usuario autenticado que realiza la verificación (`request.user`).
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/usuarios/views.py`
  - **Test:** Permite vinculación exitosa aún cuando el usuario inicia el bot manualmente sin usar el deep link completo.

---

## Ajuste 4.E — Permisos de Lectura de Catálogo e Inventario para Roles Médicos y Clínicos

### Historia de Usuario HU-AJUSTE-BK-05: Acceso de lectura al catálogo de inventario para médicos y solicitantes
> **Como** usuario con rol Doctor, Asistente o solicitante de materiales,  
> **Quiero** poder consultar las áreas, categorías, materiales y lotes disponibles en el inventario,  
> **Para** seleccionar el material a solicitar o registrar salidas sin recibir errores de permisos.

- [x] ✅ **T-AJUSTE-BK.12**: Apertura de endpoints GET en catálogo de inventario (`/areas`, `/categorias`, `/materiales`, `/lotes`).
  - **Qué hace:** Permite que cualquier usuario autenticado (`permissions.IsAuthenticated`) pueda consultar vía GET la lista y detalle de áreas, categorías, catálogo de materiales y lotes. Las operaciones de mutación (POST, PATCH, DELETE) continúan estrictamente protegidas bajo los permisos `gestionar_catalogo_inventario`, `crear_material` y `registrar_entrada`.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/views.py`
  - **Test:** Suite global 79/79 tests OK. Verificación de acceso para rol Doctor en GET `/api/inventario/areas` y GET `/api/inventario/materiales`.

---

## Ajuste 4.F — Roles M2M, Permisos de Superadmin, Asignación de Roles y Auditoría Global

### Historia de Usuario HU-AJUSTE-BK-06: Estabilización de Permisos RBAC, Roles M2M y Auditoría Global
> **Como** Superadministrador y Administrador del sistema,  
> **Quiero** que las validaciones de roles dinámicos, asignación de roles, backups y auditoría funcionen sin errores de permisos ni de métodos HTTP,  
> **Para** gestionar la clínica y los usuarios con total seguridad operativa.

- [x] ✅ **T-AJUSTE-BK.13**: Compatibilidad con roles ManyToMany en `EsSuperadmin`, `TienePermiso` y modelo `Usuario`.
  - **Problema:** Los permisos evaluaban `user.rol == 'SUPERADMIN'`, pero los roles se encuentran vinculados a través de la relación ManyToMany `roles`. Usuarios asignados al rol Superadmin con `is_superuser=False` recibían 403 Forbidden en el historial de backups y endpoints restringidos.
  - **Qué hace:** Actualiza `EsSuperadmin` y `TienePermiso` en `permissions.py` para comprobar `user.roles.filter(es_superadmin=True).exists()`. Agrega la propiedad `@property def es_superadmin(self)` en el modelo `Usuario`.
  - **Ubicación:** `Backend/apps/usuarios/permissions.py`, `Backend/apps/usuarios/models.py`
  - **Test:** `manage.py test apps.usuarios apps.backup` (OK).

- [x] ✅ **T-AJUSTE-BK.14**: Soporte de método HTTP `PUT` en `UsuarioRolesUpdateView`.
  - **Problema:** Al actualizar los roles de un usuario desde la aplicación móvil se enviaba una petición `PUT /admin/usuarios/<id>/roles`, pero la vista solo admitía `PATCH`, retornando `HTTP 405 Method Not Allowed`.
  - **Qué hace:** Agrega el método `def put(self, request, user_id): return self.patch(request, user_id)` en `UsuarioRolesUpdateView` para soportar de forma indistinta `PUT` y `PATCH`.
  - **Ubicación:** `Backend/apps/usuarios/views.py`
  - **Test:** Verificación de asignación de roles múltiples en tests de usuarios.

- [x] ✅ **T-AJUSTE-BK.15**: Destinatarios de backup multi-rol y fallback a teléfono/WhatsApp.
  - **Problema:** La notificación de respaldo solo consultaba usuarios con `is_superuser=True`, omitiendo superadmins asignados vía roles dinámicos.
  - **Qué hace:** Filtra superadmins mediante `Q(is_superuser=True) | Q(roles__es_superadmin=True)`. En `NotificationService.enviar_mensaje`, asegura el fallback al teléfono registrado del usuario (WhatsApp/SMS) cuando Telegram no está vinculado o no entrega.
  - **Ubicación:** `Backend/apps/backup/services.py`, `Backend/apps/notificaciones/services.py`
  - **Test:** `manage.py test apps.backup` (OK).

- [x] ✅ **T-AJUSTE-BK.16**: Endpoint `GET /api/admin/auditoria` con filtros y paginación (`AuditoriaGlobalView`).
  - **Problema:** No existía un endpoint REST para que los administradores y superadministradores consultaran los registros de auditoría de acciones del sistema.
  - **Qué hace:** Implementa `AuditoriaGlobalView` con permisos `[IsAuthenticated, TienePermiso]` (código `ver_reportes_globales`), soportando filtros por `accion`, `usuario`, `fecha_inicio`, `fecha_fin` y paginación estructurada. Registra la ruta en `Backend/apps/usuarios/urls.py`.
  - **Ubicación:** `Backend/apps/auditoria/views.py`, `Backend/apps/usuarios/urls.py`
  - **Test:** Suite `apps.auditoria` (10/10 tests aprobados al 100%).

- [x] ✅ **T-AJUSTE-BK.17**: Tolerancia dual `comentario` y `comentario_resolucion` en resolución de solicitudes.
  - **Problema:** El serializador de resolución requería estrictamente la clave `comentario`, provocando errores 400 Bad Request si el cliente enviaba `comentario_resolucion`.
  - **Qué hace:** Actualiza `SolicitudResolverSerializer` para admitir tanto `comentario` como `comentario_resolucion`, mapeando la información de forma transparente.
  - **Ubicación:** `Backend/apps/inventario/serializers.py`
  - **Test:** `manage.py test apps.inventario` (OK).

- [x] ✅ **T-AJUSTE-BK.18**: Soporte `formato=json` con base64 y resumen en generación de reportes PDF.
  - **Problema:** `ReportePDFView` emitía exclusivamente binarios `application/pdf`, causando excepciones de casteo en clientes que esperan respuestas JSON con metadatos.
  - **Qué hace:** En `ReportePDFView`, si la petición solicita `formato=json` o cabecera `Accept: application/json`, devuelve una respuesta JSON estructurada con el documento en Base64, el nombre de archivo y el resumen numérico de movimientos. En `ReporteEnviarMensajeriaView`, admite parámetros de fecha y usuario directo.
  - **Ubicación:** `Backend/apps/inventario/views_reportes.py`
  - **Test:** Suite global de backend (79/79 tests aprobados al 100%).





---

## Ajuste 4.G — Correcciones de Errores Reportados (2026-09-19)

### Historia de Usuario HU-AJUSTE-BK-07: Correcciones de errores detectados en pruebas de usuario

- [x] ✅ **T-AJUSTE-BK.19**: Permisos y trailing slash en endpoint marcar-leida de notificaciones.
  - **Problema:** `POST /api/notificaciones/<id>/marcar-leida` devolvía `403 Forbidden` para superadmins porque la vista solo verificaba `notificacion.destinatario == request.user`. Además, la URL sin trailing slash generaba redirección 301 que cortaba el POST.
  - **Qué hace:** Actualiza `NotificacionMarcarLeidaView` para permitir que los superadmins marquen cualquier notificación como leída. Agrega trailing slash en `notificaciones/urls.py` para las rutas `marcar-leida/` y `marcar-todas-leidas/`. Acepta tanto POST como PATCH.
  - **Ubicación:** `Backend/apps/notificaciones/views.py`, `Backend/apps/notificaciones/urls.py`
  - **Test:** Suite `manage.py test apps.notificaciones` (OK).

- [x] ✅ **T-AJUSTE-BK.20**: Envío del archivo físico `.sql.gz` de backup al Telegram.
  - **Problema:** El servicio de backup generaba el dump pero solo enviaba un mensaje de texto por Telegram; el archivo comprimido nunca se adjuntaba.
  - **Qué hace:** Cambia la llamada de `NotificationService.enviar_mensaje(...)` por `NotificationService.enviar_documento(usuario, datos, filename, caption=mensaje)` en `BackupService`, de modo que Telegram recibe el binario como documento descargable.
  - **Ubicación:** `Backend/apps/backup/services.py`
  - **Test:** Suite `manage.py test apps.backup` (OK, Telegram fallback silencioso en CI).

- [x] ✅ **T-AJUSTE-BK.21**: Envío del archivo físico `.pdf` de reporte al Telegram.
  - **Problema:** `ReportePDFView` y `ReporteEnviarMensajeriaView` solo enviaban mensajes de texto; el PDF generado no se adjuntaba.
  - **Qué hace:** Reemplaza `NotificationService.enviar_mensaje` por `NotificationService.enviar_documento(request.user, pdf_bytes, filename, caption=mensaje)` en `views_reportes.py`.
  - **Ubicación:** `Backend/apps/inventario/views_reportes.py`
  - **Test:** Suite `manage.py test apps.inventario` (OK).

- [x] ✅ **T-AJUSTE-BK.22**: Creación atómica de lote inicial al registrar un material.
  - **Problema:** Era necesario crear primero el material y luego registrar una entrada manualmente. No había opción de stock inicial en un solo paso.
  - **Qué hace:** Agrega los campos `stock_inicial`, `cantidad_inicial`, `codigo_lote`, `fecha_caducidad`, `costo_unitario` en `MaterialCreateSerializer`. En `MaterialListCreateView.post`, si `stock_inicial > 0`, crea el `Lote` y el `RegistroAuditoria` de forma atómica dentro de `transaction.atomic()`.
  - **Ubicación:** `Backend/apps/inventario/serializers.py`, `Backend/apps/inventario/views.py`
  - **Test:** Suite `manage.py test apps.inventario` (63 tests OK).

- [x] ✅ **T-AJUSTE-BK.23**: Filtros inteligentes por categoría de auditoría y acciones granulares.
  - **Problema:** El filtro `?accion=` en `GET /api/admin/auditoria` realizaba una coincidencia estricta parcial de una sola palabra, lo que excluía acciones relacionadas (por ejemplo, filtrar por inventario omitía `INGRESO_LOTE`, `REGISTRO_SALIDA_FEFO` y `AJUSTE_INVENTARIO`).
  - **Qué hace:** En `AuditoriaGlobalView`, se implementa mapeo inteligente de categorías (`INVENTARIO`, `USUARIOS_ROLES`, `ACCESOS`, `RESPALDOS`, `REPORTES`) usando expresiones `Q(...)` para agrupar todas las acciones correspondientes, manteniendo compatibilidad con nombres de acción específicos individuales.
  - **Ubicación:** `Backend/apps/auditoria/views.py`
  - **Test:** Suite `manage.py test` (81 tests OK).

### 🧪 T-AJUSTE-BK.G — Test Global Ajuste 4.G
- [x] ✅ **T-AJUSTE-BK.G**: Suite completa `manage.py test` → **81 tests, 0 errores** (OK).

---

## Ajuste 4.H — Conteo Dinámico de Materiales por Área (2026-09-29)

### Historia de Usuario HU-AJUSTE-BK-08: Métricas de área y resolución de conteo de materiales
- [x] ✅ **T-AJUSTE-BK.24**: Conteo dinámico y serialización de `cantidad_materiales` en áreas.
  - **Problema:** En la pantalla principal y en la vista de inventario, las tarjetas de áreas mostraban "0 materiales" a pesar de existir materiales creados y activos en la base de datos.
  - **Qué hace:** Agrega anotación de agregación en `AreaListCreateView.get()` mediante `Count('materiales', filter=Q(materiales__activo=True))` como `total_materiales_anotados`. En `AreaSerializer`, implementa el campo `cantidad_materiales` como `SerializerMethodField` con fallback al conteo directo de materiales activos si la anotación no estuviera presente.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/serializers.py`, `file:///home/v4/Ceos/Backend/apps/inventario/views.py`
  - **Test:** Suite `manage.py test apps.inventario` (50 tests OK al 100%).

---

## Ajuste 4.I — Vinculación y Filtrado de Categorías por Área (2026-09-29)

### Historia de Usuario HU-AJUSTE-BK-09: Relación Área-Categoría y filtrado contextual en inventario
- [x] ✅ **T-AJUSTE-BK.25**: Modelo `CategoriaMaterial.area`, filtrado por `?area_id` y asignación en creación/edición.
  - **Problema:** Las categorías no tenían relación directa con un área clínica en la base de datos ni se filtraban en `GET /inventario/categorias`, haciendo que categorías de todas las áreas se mostraran entremezcladas al usuario sin importar el área clínica activa.
  - **Qué hace:**
    1. Agrega el campo ForeignKey opcional `area = models.ForeignKey(Area, on_delete=models.CASCADE, null=True, blank=True, related_name='categorias')` en el modelo `CategoriaMaterial`.
    2. Aplica migración `0004_categoriamaterial_area_and_more.py`.
    3. Actualiza `CategoriaMaterialSerializer` exponiendo `area_id` y `area_nombre`.
    4. Actualiza `CategoriaMaterialCreateUpdateSerializer` permitiendo enviar opcionalmente `area_id`.
    5. Actualiza `CategoriaListCreateView.get()` para que al recibir el query param `?area_id`, filtre por `Q(area_id=area_id) | Q(materiales__area_id=area_id)`.
    6. Actualiza `CategoriaListCreateView.post()` y `CategoriaDetailView.put/patch()` para asociar y persistir el `area_id` correspondiente al crear o editar categorías.
  - **Ubicación:** `file:///home/v4/Ceos/Backend/apps/inventario/models.py`, `file:///home/v4/Ceos/Backend/apps/inventario/serializers.py`, `file:///home/v4/Ceos/Backend/apps/inventario/views.py`, `file:///home/v4/Ceos/Backend/apps/inventario/migrations/0004_categoriamaterial_area_and_more.py`
  - **Test:** `Backend/apps/inventario/tests/test_catalogo_materiales.py::CatalogoMaterialesEpica2ATestCase.test_t_ajuste_bk_25_categoria_filtro_por_area_y_creacion` (51/51 tests OK).

### 🧪 T-AJUSTE-BK.I — Test Global Ajuste 4.I
- [x] ✅ **T-AJUSTE-BK.I**: Suite completa `manage.py test apps.inventario` → **51 tests, 0 errores** (OK al 100%).

