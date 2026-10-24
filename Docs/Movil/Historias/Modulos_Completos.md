# App Móvil CEOS — Historias de Usuario Frontend (Flutter)

> Numeración de historias de frontend: **HU-401** en adelante (separada de la numeración de backend HU-1xx/2xx/3xx, para diferenciar claramente ambos frentes en el tablero).
> Formato: Épica → Historia de Usuario → Criterios de aceptación → Tareas técnicas → Test de la épica.
> Ajuste aplicado: **Canal de mensajería activo** ahora es exclusivo de **Superadmin** (antes decía Administrador también).

---

## ÉPICA 4.0 — Configuración Inicial del Proyecto

### HU-400: Como desarrollador, quiero tener el proyecto Flutter configurado con todas las dependencias necesarias, para poder empezar a construir las pantallas sin fricción de setup a mitad de camino.

**Criterios de aceptación:**
- El proyecto compila desde cero con `flutter pub get` sin errores de dependencias.
- Incluye manejo de estado (Riverpod), navegación (go_router), cliente HTTP (Dio), almacenamiento seguro de tokens, tipografía (Google Fonts) e íconos (Phosphor).
- Versiones fijadas de forma explícita (no `any`), para evitar romperse por actualizaciones automáticas inesperadas.

**Tareas técnicas:**
- [ ] **T-400.1** Crear el proyecto base (`flutter create ceos_app`).
- [ ] **T-400.2** Definir `pubspec.yaml` con las dependencias del stack acordado (ver archivo adjunto).
- [ ] **T-400.3** Configurar estructura de carpetas inicial (`core/`, `models/`, `repositories/`, `providers/`, `screens/`, `widgets/`) según lo definido al arrancar el frontend.
- [ ] **T-400.4** Conectar `ceos_theme.dart` (ya generado) en `main.dart` (`theme`, `darkTheme`, `themeMode`).
- [ ] **T-400.5** Configurar variables de entorno para la URL base de la API (`core/config/`), diferenciando entorno local de producción.
- [ ] **T-400.6** Configurar interceptor de Dio para adjuntar el `access_token` automáticamente y manejar el refresh de sesión (conectado a `POST /auth/refresh`).

### 🧪 T-400.T — Test de la Épica 4.0
- [ ] Verificación de que `flutter pub get` y `flutter analyze` corren sin errores, smoke test de arranque de la app (llega a la pantalla de Login sin excepciones), verificación de que el interceptor de Dio agrega el token correctamente en una request simulada.

---

## ÉPICA 4.A — Navegación y Estructura General

### HU-401: Como usuario autenticado, quiero ver un menú de navegación armado según mis permisos reales, para no ver opciones que no puedo usar ni perderme funciones que sí tengo disponibles.

**Criterios de aceptación:**
- El bottom navigation y la sección "Administración" se arman dinámicamente a partir de `permisos_efectivos`, nunca por nombre de rol hardcodeado.
- Cada ítem de menú declara qué permiso necesita para mostrarse.
- Máximo 5 ítems en el bottom nav; el resto vive en Administración.
- La sección Administración solo aparece si el usuario tiene al menos un permiso administrativo.

**Tareas técnicas:**
- [ ] **T-401.1** Definir modelo `ItemNavegacion` (label, ícono, ruta, `permisoRequerido`).
- [ ] **T-401.2** Crear lista maestra de ítems posibles de bottom nav y de Administración.
- [ ] **T-401.3** Provider (Riverpod) `permisosEfectivosProvider` que expone la lista de permisos del usuario actual como `AsyncValue`.
- [ ] **T-401.4** Widget `ShellPrincipal` que filtra la lista maestra contra `permisosEfectivosProvider` y construye el bottom nav dinámicamente.
- [ ] **T-401.5** Configurar `go_router` con las rutas del shell y un `redirect` centralizado (ver HU-403).

### HU-402: Como usuario con permisos administrativos, quiero acceder a una sección de Administración separada del uso diario, para no saturar la navegación principal.

**Criterios de aceptación:**
- Accesible desde el ícono de Perfil.
- Lista de opciones filtrada igual que el bottom nav (por permiso).
- Si el usuario no tiene ningún permiso administrativo, la opción "Administración" no aparece en absoluto (no aparece deshabilitada, se oculta).

**Tareas técnicas:**
- [ ] **T-402.1** Pantalla `AdministracionScreen` con lista de opciones (Usuarios, Roles, Sistema, Backup, Dashboard, Reportes).
- [ ] **T-402.2** Cada opción filtrada por su `permisoRequerido` contra `permisosEfectivosProvider`.
- [ ] **T-402.3** Ítem "Backup" visible únicamente si `esSuperadmin == true` (no alcanza con un permiso genérico, se valida el flag explícito).

### HU-403: Como sistema, debo esperar a tener los permisos reales del usuario antes de renderizar cualquier pantalla de navegación, para evitar mostrar por error una vista que no corresponde (ej. ver brevemente la vista de Superadmin en una cuenta normal).

**Criterios de aceptación:**
- Mientras `permisosEfectivosProvider` está en estado `loading`, se muestra una pantalla de carga (skeleton), nunca contenido operativo real ni un estado "todo visible" por defecto.
- Los permisos se consultan en cada apertura de la app (no se cachean indefinidamente entre sesiones), dado que pueden cambiar en caliente desde el backend.
- Ante `error` en la carga de permisos, se muestra una pantalla de reintento clara, no una pantalla en blanco ni contenido parcial.

**Tareas técnicas:**
- [ ] **T-403.1** Implementar `permisosEfectivosProvider` como `FutureProvider`/`AsyncNotifier` que consulta `GET /auth/me` en cada arranque de sesión.
- [ ] **T-403.2** Widget `SkeletonHome` con bloques grises con la forma de los accesos rápidos, mostrado durante `loading`.
- [ ] **T-403.3** Pantalla de error de carga de permisos con botón "Reintentar".
- [ ] **T-403.4** Auditar el código para asegurar que ningún widget tiene un valor "por defecto visible" mientras el estado real carga (revisión explícita anti-parpadeo).

### 🧪 T-401.T — Test de la Épica 4.A
- [ ] Tests de widget: bottom nav se arma distinto según distintos sets de permisos simulados, ítem Administración oculto sin permisos administrativos, ítem Backup visible solo con `esSuperadmin`, estado `loading` nunca renderiza contenido operativo (test de regresión anti-parpadeo).

---

## ÉPICA 4.B — Autenticación

### HU-404: Como usuario, quiero iniciar sesión con usuario/correo y contraseña desde una pantalla simple, para acceder a la app.

**Criterios de aceptación:**
- Un solo input para usuario/correo (sin distinguir cuál es), campo de contraseña con mostrar/ocultar.
- Autocompletado del sistema operativo desactivado explícitamente en el campo de usuario (por uso en dispositivos compartidos).
- Estados de error diferenciados: credenciales incorrectas vs. cuenta bloqueada temporalmente, con mensajes humanos.
- Botón de login deshabilitado + spinner mientras espera respuesta, evitando doble envío.

**Tareas técnicas:**
- [ ] **T-404.1** Pantalla `LoginScreen` con formulario y validación básica de campos no vacíos.
- [ ] **T-404.2** `AuthRepository.login()` que llama `POST /auth/login` y maneja los distintos códigos de error del backend.
- [ ] **T-404.3** `AuthNotifier` (Riverpod) con estados `idle / loading / error / autenticado`.
- [ ] **T-404.4** Almacenamiento seguro de `access_token`/`refresh_token` (`flutter_secure_storage`).
- [ ] **T-404.5** Mapeo de códigos de error del backend a mensajes de usuario (catálogo de textos, no mostrar errores técnicos crudos).

### HU-405: Como usuario nuevo, quiero completar el flujo obligatorio de primer login (contraseña, Telegram, teléfono) con un stepper visual, para entender cuánto falta y no perderme en el proceso.

**Criterios de aceptación:**
- Stepper con indicador de progreso (1 de 3, 2 de 3, 3 de 3), no se puede saltar pasos ni volver a pantallas anteriores del flujo normal de la app hasta completarlo.
- Paso 1: validación en vivo de requisitos de contraseña con checks visuales.
- Paso 2: deep link a Telegram + estado "esperando confirmación" + botón manual de reverificación.
- Paso 3: input de OTP de 6 dígitos con auto-avance entre casillas, botón de reenvío respetando el rate limit (60s) con cuenta regresiva visual.

**Tareas técnicas:**
- [ ] **T-405.1** Widget reutilizable `StepperProgreso` (indicador de pasos genérico).
- [ ] **T-405.2** Pantalla `CambiarPasswordStep` con validador de contraseña en vivo (widget reutilizable, ver T-406.3).
- [ ] **T-405.3** Pantalla `VincularTelegramStep`: botón deep link + polling o refresco manual del estado de vinculación.
- [ ] **T-405.4** Pantalla `ConfirmarTelefonoStep`: envío de OTP + widget reutilizable `InputCodigoOTP` (6 dígitos, auto-avance).
- [ ] **T-405.5** `PrimerLoginNotifier` que coordina el estado de los 3 pasos y bloquea el acceso al resto de la app (`go_router redirect`) mientras `primerLoginCompletado == false`.
- [ ] **T-405.6** Lógica de rate limit visual: deshabilitar botón "Reenviar" con cuenta regresiva de 60s sincronizada con la respuesta del backend.

### HU-406: Como usuario, quiero recuperar mi contraseña mediante un código enviado a mi canal de notificación, para acceder al sistema sin depender de que alguien más esté disponible.

**Criterios de aceptación:**
- 3 pantallas: solicitar (usuario/correo), verificar código, definir nueva contraseña.
- Mensaje neutro tras solicitar, sin confirmar ni negar si el usuario existe.
- Contador de intentos fallidos visibles (máx. 3, reflejando el límite del backend).
- Reutiliza el widget `InputCodigoOTP` del primer login.

**Tareas técnicas:**
- [ ] **T-406.1** Pantalla `SolicitarRecuperacionScreen` → `POST /auth/recuperar/solicitar`.
- [ ] **T-406.2** Pantalla `VerificarCodigoScreen` reutilizando `InputCodigoOTP`, mostrando intentos restantes según respuesta del backend.
- [ ] **T-406.3** Widget reutilizable `ValidadorPasswordEnVivo` (checks de requisitos con ícono de check verde progresivo).
- [ ] **T-406.4** Pantalla `NuevaPasswordScreen` → `POST /auth/recuperar/nueva-contrasena`, con redirección a Login y mensaje de éxito al terminar.

### 🧪 T-404.T — Test de la Épica 4.B
- [ ] Tests de widget/integración: login exitoso y fallido con mensajes correctos, bloqueo de navegación durante primer login incompleto, avance automático del input OTP, validación en vivo de contraseña reflejando reglas reales, flujo completo de recuperación de contraseña de principio a fin (mockeando backend).

---

## ÉPICA 4.C — Home

### HU-407: Como usuario, quiero ver una pantalla de inicio con accesos rápidos relevantes a mis permisos, para llegar a mis acciones más frecuentes en un solo toque.

**Criterios de aceptación:**
- Grid de accesos rápidos filtrado por permiso (mismo patrón que la navegación general).
- Encabezado con nombre, chip de rol activo con color, e ícono de notificaciones con contador.
- Estado vacío con mensaje positivo cuando no hay accesos aplicables o actividad (nunca una sección en blanco sin explicación).

**Tareas técnicas:**
- [ ] **T-407.1** Pantalla `HomeScreen` única, sin variantes por nombre de rol.
- [ ] **T-407.2** Lista maestra de accesos rápidos posibles (ítem, ícono, ruta, `permisoRequerido`), reutilizando el mismo patrón de `ItemNavegacion` de T-401.1.
- [ ] **T-407.3** Widget `ChipRolActivo` con color e ícono según el rol visible del usuario.
- [ ] **T-407.4** Widget `IconoNotificaciones` con badge de contador, conectado a `GET /notificaciones`.

### HU-408: Como usuario con permiso de ver alertas de inventario, quiero ver un resumen de alertas activas en mi Home, para actuar rápido sin tener que buscarlas.

**Criterios de aceptación:**
- Sección visible solo con el permiso correspondiente.
- Cada alerta usa el color de estado correcto (ámbar/coral) y es tocable, llevando directo al material/lote afectado.
- Estado vacío con mensaje positivo ("Todo el inventario está en orden") cuando no hay alertas.

**Tareas técnicas:**
- [ ] **T-408.1** `InventarioRepository.obtenerAlertasActivas()` (consume el cálculo ya expuesto por el backend).
- [ ] **T-408.2** Widget `TarjetaAlerta` con franja de color según severidad y navegación al detalle al tocar.
- [ ] **T-408.3** Estado vacío con ícono `stockOk` y mensaje positivo.

### HU-409: Como usuario, quiero ver mi actividad reciente en el Home, para tener continuidad de lo que hice últimamente sin entrar al historial completo.

**Criterios de aceptación:**
- Lista de 3 a 5 movimientos propios más recientes.
- Estado vacío con mensaje claro para usuarios nuevos sin actividad aún.

**Tareas técnicas:**
- [ ] **T-409.1** Consumir `GET /usuarios/{id}/historial` limitado a los últimos registros.
- [ ] **T-409.2** Widget `ItemActividadReciente` (ícono según tipo de acción, texto corto, tiempo relativo tipo "hace 2h").

### HU-410: Como usuario desactivado, quiero ver una vista restringida al iniciar sesión, para consultar solo mi historial y reportes sin acceder al resto del sistema.

**Criterios de aceptación:**
- No usa el shell de navegación normal (sin bottom nav completo).
- Solo 2 opciones visibles: "Mi historial" y "Mis reportes", más botón de cerrar sesión.
- Se activa automáticamente según la respuesta de `GET /auth/me` (`activo: false`), sin lógica adicional en el frontend más allá de leer ese estado.

**Tareas técnicas:**
- [ ] **T-410.1** Pantalla `VistaRestringidaScreen`, separada del `ShellPrincipal`.
- [ ] **T-410.2** `redirect` de `go_router` que envía a esta pantalla cuando `activo == false`, antes de llegar a cualquier otra ruta protegida.

### 🧪 T-407.T — Test de la Épica 4.C
- [ ] Tests de widget: Home muestra accesos distintos según permisos simulados, sección de alertas oculta sin permiso, estado vacío positivo cuando no hay alertas/actividad, usuario desactivado es redirigido correctamente a la vista restringida y no puede navegar fuera de ella.

---

## ÉPICA 4.D — Inventario

### HU-411: Como usuario, quiero elegir primero el Área (Odontología/Estética) al entrar a cualquier flujo de inventario, para no tener que filtrar manualmente después.

**Criterios de aceptación:**
- Pantalla/paso de selección de Área como punto de entrada de: Consulta de inventario, Nueva entrada, Nueva salida, Solicitud.
- Cada tarjeta de Área muestra su color, ícono y contador de materiales activos.
- El área elegida queda fijada durante todo el flujo siguiente (no se vuelve a pedir).

**Tareas técnicas:**
- [ ] **T-411.1** Widget reutilizable `SelectorArea` (2 tarjetas, colores `areaOdontologia`/`areaEstetica` del theme).
- [ ] **T-411.2** Provider de estado temporal `areaSeleccionadaProvider`, con scope acotado al flujo activo (se limpia al salir).
- [ ] **T-411.3** Integrar `area_id` automáticamente en las llamadas subsiguientes de cada flujo (`GET /inventario/materiales?area_id=`, etc.).

### HU-412: Como usuario, quiero buscar y filtrar materiales dentro de un Área, para encontrar lo que necesito rápido.

**Criterios de aceptación:**
- Búsqueda por texto libre con debounce (~400ms).
- Chips de filtro por Categoría, horizontales y scrolleables, con ícono Phosphor de cada una.
- Cada resultado usa el patrón de franja de estado (verde/ámbar/coral) + stock en `dataMono`.

**Tareas técnicas:**
- [ ] **T-412.1** Pantalla `ListaMaterialesScreen` con `SearchBar` + debounce.
- [ ] **T-412.2** Widget `ChipsCategoria` (scroll horizontal, multi-selección opcional).
- [ ] **T-412.3** Widget reutilizable `CardMaterial` (franja de estado + ícono de categoría + stock).
- [ ] **T-412.4** `InventarioRepository.buscarMateriales(query, areaId, categoriaId)`.

### HU-413: Como usuario, quiero ver el detalle de un material con sus lotes, historial y ajustes en tabs separadas, para consultar toda su información sin saturar una sola pantalla.

**Criterios de aceptación:**
- Tab "Lotes": ordenados por vencimiento, con indicador de alerta activa.
- Tab "Historial de movimientos": entradas/salidas (sin exponer número de lote técnico, ver HU-415).
- Tab "Ajustes": visible solo con permiso `ajustar_inventario`, separada del historial normal (según HU-210).
- Accesos directos a acciones (entrada/salida/solicitud) filtrados por permiso.

**Tareas técnicas:**
- [ ] **T-413.1** Pantalla `DetalleMaterialScreen` con `TabBar` (Lotes / Historial / Ajustes condicional).
- [ ] **T-413.2** Widget `ItemLote` (fecha de caducidad, cantidad disponible, indicador de alerta).
- [ ] **T-413.3** Widget `ItemMovimientoHistorial` diferenciado por tipo (entrada/salida/ajuste, con íconos distintos).
- [ ] **T-413.4** Botones de acción filtrados por `permisosEfectivosProvider`.

### HU-414: Como usuario con permiso, quiero registrar el ingreso de un lote nuevo, para sumar stock con su fecha de vencimiento.

**Criterios de aceptación:**
- Formulario: cantidad, fecha de caducidad, fecha de alerta (sugerida automáticamente, editable), costo opcional.
- Validación en vivo: fecha de alerta no puede ser posterior a la de caducidad.
- Confirmación regresa al detalle del material con el lote ya visible.

**Tareas técnicas:**
- [ ] **T-414.1** Pantalla `NuevaEntradaScreen` con formulario y date pickers.
- [ ] **T-414.2** Lógica de sugerencia automática de fecha de alerta (ej. -30 días de la caducidad), editable por el usuario.
- [ ] **T-414.3** Validación de formulario en el cliente antes de enviar (espejo de las reglas del backend, sin reemplazarlas).
- [ ] **T-414.4** `InventarioRepository.registrarEntrada()` → `POST /inventario/lotes`.

### HU-415: Como usuario con permiso, quiero registrar una salida de material con un paso de revisión simple antes de confirmar, para evitar errores sin necesidad de ver información técnica de lotes.

**Criterios de aceptación:**
- Flujo: cantidad → pantalla de revisión ("Vas a registrar la salida de X unidades de [material]") → confirmar.
- El mensaje final de éxito solo menciona material y cantidad, nunca lotes ni fechas de vencimiento.
- El detalle completo de distribución FEFO (lotes afectados) se guarda igualmente vía el backend y queda disponible en el historial detallado del material, no en este flujo.
- Si el backend rechaza por stock insuficiente, se muestra el mensaje accionable correspondiente, con botón a "Hacer ajuste" solo si el usuario tiene ese permiso.

**Tareas técnicas:**
- [ ] **T-415.1** Pantalla `NuevaSalidaScreen` con paso de cantidad.
- [ ] **T-415.2** Pantalla `RevisionSalidaScreen` (mensaje simple, sin datos de lote).
- [ ] **T-415.3** `InventarioRepository.registrarSalida()` → `POST /inventario/salidas`, manejando la respuesta de error de stock insuficiente (código/estructura ya definida en T-208.3).
- [ ] **T-415.4** Renderizado condicional del botón "Hacer ajuste" en el mensaje de error, según `permisosEfectivosProvider`.

### HU-416: Como usuario con permiso, quiero hacer un ajuste manual de un lote con motivo obligatorio, para corregir diferencias entre el stock físico y el digital.

**Criterios de aceptación:**
- Selector de lote específico, campo de cantidad nueva, selector de motivo (catálogo corto + opción "Otro" con texto libre).
- Confirmación explícita mostrando el cambio antes de aplicar ("¿confirmas cambiar de X a Y unidades?").
- Aplica de inmediato, sin pantalla de aprobación adicional.

**Tareas técnicas:**
- [ ] **T-416.1** Pantalla `AjusteInventarioScreen`.
- [ ] **T-416.2** Widget de confirmación con resumen del cambio antes de enviar.
- [ ] **T-416.3** `InventarioRepository.registrarAjuste()` → `POST /inventario/ajustes`.

### HU-417: Como usuario con permiso de solicitar, quiero crear una solicitud de material indicando el motivo, para pedir reposición.

**Criterios de aceptación:**
- Flujo: Área → Material → cantidad → motivo (sugerido automático si stock es 0, editable) → comentario opcional → enviar.

**Tareas técnicas:**
- [ ] **T-417.1** Pantalla `CrearSolicitudScreen` reutilizando `SelectorArea` y selector de material.
- [ ] **T-417.2** Lógica de sugerencia automática de motivo según stock consultado.
- [ ] **T-417.3** `InventarioRepository.crearSolicitud()` → `POST /inventario/solicitudes`.

### HU-418: Como Doctor, quiero ver mis solicitudes con su estado y poder editar/cancelar las pendientes, para gestionar mis propios pedidos.

**Criterios de aceptación:**
- Lista con badge de color por estado (pendiente/aprobada/rechazada/cancelada).
- Botones "Editar"/"Cancelar" visibles únicamente en solicitudes `pendiente` y propias.

**Tareas técnicas:**
- [ ] **T-418.1** Pantalla `MisSolicitudesScreen`.
- [ ] **T-418.2** Widget reutilizable `BadgeEstado` (colores del theme según estado).
- [ ] **T-418.3** Pantalla `EditarSolicitudScreen` → `PATCH /inventario/solicitudes/{id}`.
- [ ] **T-418.4** Acción de cancelar → `POST /inventario/solicitudes/{id}/cancelar` con confirmación.

### HU-419: Como GestorInventario, quiero ver y resolver solicitudes pendientes, para gestionar la reposición de material.

**Criterios de aceptación:**
- Lista de pendientes con motivo destacado como badge.
- Pantalla de resolución con botones Aprobar/Rechazar; rechazar exige comentario obligatorio antes de confirmar.

**Tareas técnicas:**
- [ ] **T-419.1** Pantalla `SolicitudesPendientesScreen`.
- [ ] **T-419.2** Pantalla `ResolverSolicitudScreen` con validación de comentario obligatorio en rechazo.
- [ ] **T-419.3** `InventarioRepository.resolverSolicitud()` → `POST /inventario/solicitudes/{id}/resolver`.

### HU-420: Como Administrador, quiero ver todas las solicitudes del sistema en modo solo lectura, para tener visibilidad total.

**Criterios de aceptación:**
- Lista filtrable por usuario, material, motivo, estado; sin botones de acción.

**Tareas técnicas:**
- [ ] **T-420.1** Pantalla `TodasSolicitudesScreen` con filtros combinables.
- [ ] **T-420.2** Reutilizar `BadgeEstado` (T-418.2) sin acciones asociadas.

### HU-421: Como Administrador/Superadmin, quiero generar reportes PDF por fecha/rango y opcionalmente por usuario, y recibirlos por descarga o mensajería.

**Criterios de aceptación:**
- Selector de fecha única o rango, selector opcional de usuario.
- Botones "Descargar" y "Enviar por [canal activo]" tras generar (texto del botón refleja el canal real).

**Tareas técnicas:**
- [ ] **T-421.1** Pantalla `GenerarReportePDFScreen` con selectores de fecha y usuario (autocomplete).
- [ ] **T-421.2** `InventarioRepository.generarReporte()` → `POST /inventario/reportes/pdf`.
- [ ] **T-421.3** Integración de descarga de archivo en el dispositivo (`open_filex` o similar) y botón de envío → `POST /inventario/reportes/{id}/enviar-por-mensajeria`.
- [ ] **T-421.4** Consultar el canal activo actual para rotular el botón dinámicamente ("Enviar por Telegram" / "Enviar por WhatsApp").

### HU-422: Como Administrador, quiero ver el dashboard de materiales más usados, el panel de reposición preventiva y el reporte de gastos.

**Criterios de aceptación:**
- Selector de rango de fechas (default 30 días) + filtros de área/categoría.
- Ranking como lista ordenada con barra de proporción visual.
- Panel de reposición preventiva en card separada.
- Reporte de gastos en 2 tabs (categoría/material) con aviso de "⚠ costo incompleto" cuando aplica.

**Tareas técnicas:**
- [ ] **T-422.1** Pantalla `DashboardScreen` con selector de rango y filtros.
- [ ] **T-422.2** Widget `RankingMaterial` (lista + barra proporcional simple, sin librería de gráficos pesada).
- [ ] **T-422.3** Widget `CardReposicionPreventiva`.
- [ ] **T-422.4** Pantalla `ReporteGastosScreen` con `TabBar` (categoría/material) y badge de advertencia de costo incompleto.

### HU-423: Como Administrador o GestorInventario, quiero elegir un ícono visual desde una lista curada al crear/editar un Área o Categoría, para identificarla sin usar imágenes.

**Criterios de aceptación:**
- Selector visual tipo grilla con los íconos disponibles (consultados desde `GET /inventario/iconos-disponibles`).
- Búsqueda local (offline) por palabra clave dentro de la lista curada.
- Si no se elige ninguno, se aplica el ícono de fallback definido por el backend.

**Tareas técnicas:**
- [ ] **T-423.1** Agregar dependencia `phosphor_flutter` al proyecto.
- [ ] **T-423.2** Mapeo fijo `identificador (String) → IconData` de Phosphor en el cliente.
- [ ] **T-423.3** Widget `SelectorIconoGrid` con búsqueda local por texto sobre la lista curada.
- [ ] **T-423.4** Integrar el selector en los formularios de creación/edición de Área y Categoría.

### 🧪 T-411.T — Test de la Épica 4.D
- [ ] Tests de widget/integración: selección de Área persiste correctamente durante todo un flujo, búsqueda con debounce no dispara llamadas de más, flujo de salida no expone información de lote en ningún mensaje visible, validación de fechas en nueva entrada, botón "Hacer ajuste" condicionado a permisos tras error de stock, resolución de solicitud exige comentario en rechazo, selector de íconos filtra correctamente offline.

---

## ÉPICA 4.E — Administración

### HU-424: Como Administrador/Superadmin, quiero gestionar usuarios (listar, crear, editar, desactivar/reactivar, cerrar sesión remota), desde el móvil.

**Criterios de aceptación:**
- Lista con búsqueda, filtro por rol/estado; inactivos visibles pero atenuados.
- Detalle con edición de rol(es), acción de desactivar/reactivar con confirmación explicando la consecuencia, y cierre de sesión remoto.
- Creación de usuario con pantalla final de "copiar credenciales" mostrada una sola vez.

**Tareas técnicas:**
- [ ] **T-424.1** Pantalla `ListaUsuariosScreen` con búsqueda y filtros.
- [ ] **T-424.2** Pantalla `DetalleUsuarioScreen` con edición de roles (multi-check) y tab de historial/auditoría.
- [ ] **T-424.3** Acciones de desactivar/reactivar y cerrar sesión remota con diálogos de confirmación explicativos.
- [ ] **T-424.4** Pantalla `CrearUsuarioScreen` + pantalla `CredencialesGeneradasScreen` (con botón de copiar, mostrada una única vez tras la creación).

### HU-425: Como Superadmin, quiero crear y editar roles con sus permisos agrupados por módulo, para adaptar el sistema a como trabaja la clínica.

**Criterios de aceptación:**
- Lista de roles con badge "de fábrica"/"personalizado"; Superadmin visible pero no editable.
- Permisos agrupados por módulo (Usuarios, Inventario, Solicitudes, Reportes, Sistema) en la pantalla de edición.

**Tareas técnicas:**
- [ ] **T-425.1** Pantalla `ListaRolesScreen`.
- [ ] **T-425.2** Pantalla `EditarRolScreen` con checkboxes de permisos agrupados por sección colapsable.
- [ ] **T-425.3** Bloqueo explícito en la UI para el rol Superadmin (campos deshabilitados + nota informativa).

### HU-426: Como Superadmin, quiero configurar el canal de mensajería activo del sistema y el envío de alertas de inventario, desde una pantalla exclusiva para mi rol.

**Criterios de aceptación:**
- Pantalla "Configuración del Sistema" visible únicamente si `esSuperadmin == true` (no basta un permiso administrativo genérico).
- Selector Telegram/WhatsApp con indicador de canal activo; WhatsApp deshabilitado con nota si Twilio no está configurado.
- Switch de alertas de inventario con texto aclaratorio de que el cálculo interno sigue activo aunque se apague el envío.

**Tareas técnicas:**
- [ ] **T-426.1** Pantalla `ConfiguracionSistemaScreen`, con guard de acceso explícito por `esSuperadmin` (no por permiso genérico de Administración).
- [ ] **T-426.2** Selector de canal → `PATCH /admin/config/canal-mensajeria`.
- [ ] **T-426.3** Switch de alertas → `PATCH /admin/config/alertas-inventario`.
- [ ] **T-426.4** Ocultar/deshabilitar la opción WhatsApp según el estado de configuración de Twilio reportado por el backend.

### HU-427: Como Superadmin, quiero generar backups manuales y ver el historial de respaldos, desde una sección exclusiva para mi rol.

**Criterios de aceptación:**
- Sección visible únicamente para Superadmin.
- Botón "Generar backup ahora" con confirmación y estado de carga.
- Historial con fecha, origen, estado y tamaño; fallidos resaltados en color de alerta.

**Tareas técnicas:**
- [ ] **T-427.1** Pantalla `BackupScreen` con guard de acceso exclusivo por `esSuperadmin`.
- [ ] **T-427.2** Botón de generación manual → `POST /admin/backup/generar`, con polling de estado (`GET /admin/backup/estado/{tarea_id}`).
- [ ] **T-427.3** Pantalla `HistorialBackupScreen` con filtros de fecha/estado → `GET /admin/backup/historial`.

### 🧪 T-424.T — Test de la Épica 4.E
- [ ] Tests de widget/integración: acciones de usuario reflejan confirmaciones correctas antes de aplicarse, edición de rol Superadmin bloqueada en la UI, pantalla de Configuración del Sistema y Backup inaccesibles para un usuario Administrador sin flag `esSuperadmin` (verificación explícita de que un permiso administrativo genérico no basta), switch de alertas refleja el estado real del backend.

---

## Resumen para el tablero

| Épica | # Historias | Prioridad sugerida |
|---|---|---|
| 4.0 Configuración Inicial del Proyecto | 1 (HU-400) | Bloqueante absoluta — primer paso, antes que cualquier pantalla |
| 4.A Navegación y Estructura General | 3 (HU-401 a 403) | Muy alta — bloqueante para todo lo demás |
| 4.B Autenticación | 3 (HU-404 a 406) | Muy alta |
| 4.C Home | 4 (HU-407 a 410) | Alta |
| 4.D Inventario | 13 (HU-411 a 423) | Alta — el módulo más grande |
| 4.E Administración | 4 (HU-424 a 427) | Media-alta |

**Total: 28 historias de usuario de frontend.**

**Orden de desarrollo recomendado:** 4.0 (setup del proyecto) → 4.A (shell y navegación dinámica) → 4.B (autenticación, sin esto no se puede probar nada más) → 4.C (Home) → 4.D (Inventario, el bloque más grande, conviene dividirlo en sub-sprints: catálogo/consulta → entradas/salidas → ajustes → solicitudes → reportes/dashboard) → 4.E (Administración, al final porque depende de tener usuarios/roles reales para probar contra el backend).