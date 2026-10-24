# Módulo 2 — Inventario de Materiales
## Desglose de Tareas Backend (Scrumban)

> Formato: Épica → Historia de Usuario → Tareas técnicas atómicas → Tarea de Test de la épica.
> Continúa la numeración de tareas del Módulo 1 (T-1xx) a partir de **T-2xx**.

---

## ÉPICA 2.A — Catálogo de Materiales (Áreas, Categorías, Materiales)

### HU-201: CRUD de Áreas

- [ ] **T-201.1** Crear modelo `Area` (nombre, descripción, `activo` default true).
- [ ] **T-201.2** Endpoint `GET /inventario/areas` (listar).
- [ ] **T-201.3** Endpoint `POST /inventario/areas` restringido a permiso `gestionar_catalogo_inventario`.
- [ ] **T-201.4** Endpoint `PATCH /inventario/areas/{id}` (editar nombre/descripción).
- [ ] **T-201.5** Endpoint `DELETE /inventario/areas/{id}` con validación: si tiene materiales asociados, rechazar el borrado y sugerir desactivar (`activo = false`) en su lugar.

### HU-202: CRUD de Categorías de material

- [ ] **T-202.1** Crear modelo `CategoriaMaterial` (nombre, descripción, `activo` default true).
- [ ] **T-202.2** Endpoint `GET /inventario/categorias`.
- [ ] **T-202.3** Endpoint `POST /inventario/categorias` restringido a `gestionar_catalogo_inventario`.
- [ ] **T-202.4** Endpoint `PATCH /inventario/categorias/{id}`.
- [ ] **T-202.5** Endpoint `DELETE /inventario/categorias/{id}` con misma validación que T-201.5 (rechazar si tiene materiales asociados).

### HU-203: Alta de material

- [ ] **T-203.1** Crear modelo `Material` (nombre, area FK, categoria FK, unidad_medida, stock_minimo default 5, `activo` default true).
- [ ] **T-203.2** Endpoint `POST /inventario/materiales` restringido a `gestionar_catalogo_inventario`.
- [ ] **T-203.3** Validación de unicidad de nombre dentro de la combinación area+categoria.
- [ ] **T-203.4** Endpoint `PATCH /inventario/materiales/{id}` (editar nombre, área, categoría, unidad, stock mínimo).
- [ ] **T-203.5** Property/método `stock_total_disponible(material)` que calcula la suma de cantidades disponibles de todos sus lotes activos (se reutilizará en varias épicas siguientes).

### HU-204: Búsqueda y filtrado de materiales

- [ ] **T-204.1** Endpoint `GET /inventario/materiales` con soporte de query params: `busqueda` (texto libre sobre nombre), `area_id`, `categoria_id`.
- [ ] **T-204.2** Implementar búsqueda case-insensitive y por coincidencia parcial (ej. `ILIKE` o equivalente).
- [ ] **T-204.3** Incluir en la respuesta el stock actual calculado (T-203.5) y un campo de estado derivado (`normal` / `bajo_minimo` / `con_lotes_por_vencer`).
- [ ] **T-204.4** Agregar índices de base de datos sobre `nombre`, `area_id`, `categoria_id` para que el filtrado sea eficiente.

### 🧪 T-201.T — Test de la Épica 2.A
- [ ] Suite de tests: CRUD de áreas y categorías, bloqueo de borrado cuando tienen materiales asociados, creación de material con validación de unicidad por área+categoría, cálculo correcto de `stock_total_disponible`, búsqueda por texto libre y filtros combinados por área/categoría.

---

## ÉPICA 2.B — Ingreso de Lotes (Entradas)

### HU-205: Registro de ingreso de lote

- [ ] **T-205.1** Crear modelo `Lote` (material FK, cantidad_ingresada, cantidad_disponible, fecha_ingreso, fecha_caducidad, fecha_alerta_vencimiento, costo nullable, usuario_ingreso FK, `costo_registrado` booleano calculado).
- [ ] **T-205.2** Endpoint `POST /inventario/lotes` restringido a `registrar_entrada`.
- [ ] **T-205.3** Al crear el lote, setear `cantidad_disponible = cantidad_ingresada` (se irá descontando con las salidas).
- [ ] **T-205.4** Si `costo` viene vacío, marcar `costo_registrado = false` automáticamente (usado luego en reportes de gasto).
- [ ] **T-205.5** Registrar automáticamente el ingreso en auditoría (usuario, material, cantidad, timestamp) reutilizando el decorador `@auditable` del Módulo 1.
- [ ] **T-205.6** Validaciones de negocio: `fecha_caducidad` debe ser posterior a `fecha_ingreso`; `fecha_alerta_vencimiento` debe ser anterior o igual a `fecha_caducidad`.

### HU-206: Listado de lotes por material

- [ ] **T-206.1** Endpoint `GET /inventario/materiales/{id}/lotes` ordenado por `fecha_caducidad` ascendente.
- [ ] **T-206.2** Incluir en cada lote un campo calculado `alerta_activa` (booleano: `hoy >= fecha_alerta_vencimiento`).
- [ ] **T-206.3** Excluir por defecto lotes con `cantidad_disponible == 0` de la vista principal, con parámetro opcional para incluirlos (histórico).

### 🧪 T-205.T — Test de la Épica 2.B
- [ ] Suite de tests: creación de lote con y sin costo (verificando flag `costo_registrado`), validación de fechas inconsistentes, registro correcto en auditoría, listado de lotes ordenado por vencimiento, cálculo correcto de `alerta_activa`.

---

## ÉPICA 2.C — Salidas de Material (FEFO)

### HU-207: Registro de salida con descuento automático FEFO

- [ ] **T-207.1** Crear modelo `MovimientoSalida` (material FK, cantidad, usuario FK, fecha, motivo/destino texto).
- [ ] **T-207.2** Crear modelo intermedio `MovimientoSalidaLote` (movimiento_salida FK, lote FK, cantidad_descontada_de_este_lote) — permite que una salida se reparta entre varios lotes.
- [ ] **T-207.3** Implementar función `calcular_distribucion_fefo(material, cantidad_solicitada)` que retorna la lista de lotes y cuánto descontar de cada uno, ordenando por `fecha_caducidad` ascendente hasta cubrir la cantidad total.
- [ ] **T-207.4** Endpoint `POST /inventario/salidas` restringido a `registrar_salida`.
- [ ] **T-207.5** Envolver la operación completa (cálculo FEFO + descuento de cada lote + creación del movimiento) en una **transacción con bloqueo a nivel de fila** (ej. `select_for_update` en Django) sobre los lotes del material, para evitar condiciones de carrera entre salidas simultáneas.
- [ ] **T-207.6** Registrar en auditoría cada salida (usuario, material, cantidad total, lotes afectados, timestamp).

### HU-208: Bloqueo de salida mayor al stock disponible

- [ ] **T-208.1** Antes de aplicar el descuento (dentro de la misma transacción de T-207.5), validar que `stock_total_disponible(material) >= cantidad_solicitada`.
- [ ] **T-208.2** Si la validación falla, abortar la transacción (rollback) y no crear ningún registro de movimiento.
- [ ] **T-208.3** Respuesta de error estructurada que incluya: cantidad disponible actual, cantidad solicitada, y un flag `puede_ajustar` según si el usuario autenticado tiene el permiso `ajustar_inventario` (para que el frontend decida si muestra el botón de acceso directo al ajuste).

### 🧪 T-207.T — Test de la Épica 2.C
- [ ] Suite de tests: salida que se reparte correctamente entre dos lotes por FEFO, rechazo total de salida que supera el stock (sin dejar registros parciales), simulación de dos salidas concurrentes sobre el mismo material verificando que el bloqueo de fila evita sobregiro, verificación del flag `puede_ajustar` según permisos del usuario.

---

## ÉPICA 2.D — Ajustes de Inventario

### HU-209: Registro de ajuste manual

- [ ] **T-209.1** Crear modelo `AjusteInventario` (lote FK, usuario FK, cantidad_anterior, cantidad_nueva, motivo, timestamp — append-only).
- [ ] **T-209.2** Endpoint `POST /inventario/ajustes` restringido a `ajustar_inventario` (Administrador y GestorInventario).
- [ ] **T-209.3** Al aplicar el ajuste, actualizar directamente `cantidad_disponible` del lote afectado dentro de una transacción, guardando el valor anterior en el registro de ajuste.
- [ ] **T-209.4** Validar que el motivo no puede quedar vacío (texto libre o selección de catálogo de motivos frecuentes, según se decida en frontend — backend solo exige que no esté vacío).
- [ ] **T-209.5** Bloquear a nivel de API cualquier endpoint que intente modificar `cantidad_disponible` de un lote fuera de este flujo (ni por edición directa del lote, ni por otro camino).

### HU-210: Historial de ajustes separado

- [ ] **T-210.1** Endpoint `GET /inventario/ajustes` con filtros por `material_id`, `usuario_id`, rango de fechas.
- [ ] **T-210.2** Confirmar que este endpoint es independiente del historial de movimientos de entrada/salida (no comparten la misma tabla ni el mismo endpoint de consulta).
- [ ] **T-210.3** Restricción a nivel de base de datos/ORM que impida `UPDATE`/`DELETE` sobre `AjusteInventario` (mismo patrón que `RegistroAuditoria` del Módulo 1).

### 🧪 T-209.T — Test de la Épica 2.D
- [ ] Suite de tests: ajuste aplicado correctamente con actualización de `cantidad_disponible`, rechazo de ajuste sin motivo, intento de editar un lote directamente sin pasar por el ajuste (debe fallar), intento de editar/borrar un registro de ajuste ya creado (debe fallar), filtrado correcto del historial de ajustes.

---

## ÉPICA 2.E — Solicitudes de Material

### HU-211: Creación de solicitud

- [ ] **T-211.1** Crear modelo `SolicitudMaterial` (material FK, usuario_solicitante FK, cantidad, motivo enum [`sin_stock`, `reposicion_preventiva`], comentario nullable, estado enum [`pendiente`, `aprobada`, `rechazada`, `cancelada`], usuario_resolvio FK nullable, comentario_resolucion nullable, timestamps).
- [ ] **T-211.2** Endpoint `POST /inventario/solicitudes` restringido a `solicitar_material`.
- [ ] **T-211.3** Lógica de sugerencia automática de motivo: si `stock_total_disponible(material) == 0`, prellenar `motivo = "sin_stock"` en la respuesta previa al formulario (el usuario puede cambiarlo).
- [ ] **T-211.4** Al crear, setear `estado = "pendiente"`.
- [ ] **T-211.5** Disparar notificación a GestorInventario y Administrador vía `NotificationService` (canal activo) + notificación interna dentro de la app (requiere modelo `NotificacionApp` o similar, ver T-211.6).
- [ ] **T-211.6** Crear modelo `NotificacionApp` genérico (usuario_destino, tipo, mensaje, entidad_relacionada, leida booleano, timestamp) reutilizable para todo el sistema, no exclusivo de este módulo.
- [ ] **T-211.7** Endpoint `GET /notificaciones` (propias del usuario autenticado) y `PATCH /notificaciones/{id}/marcar-leida`.

### HU-212: Edición/cancelación de solicitud propia

- [ ] **T-212.1** Endpoint `PATCH /inventario/solicitudes/{id}` que permite editar cantidad, motivo y comentario.
- [ ] **T-212.2** Validar que solo el `usuario_solicitante` original puede editar, y solo si `estado == "pendiente"`.
- [ ] **T-212.3** Endpoint `POST /inventario/solicitudes/{id}/cancelar` que cambia `estado = "cancelada"`, con misma validación de dueño + estado pendiente.
- [ ] **T-212.4** Registrar en auditoría la edición y la cancelación.

### HU-213: Resolución de solicitudes (GestorInventario)

- [ ] **T-213.1** Endpoint `GET /inventario/solicitudes?estado=pendiente` restringido a `aprobar_solicitud`.
- [ ] **T-213.2** Endpoint `POST /inventario/solicitudes/{id}/resolver` (recibe `estado` [`aprobada`/`rechazada`] y `comentario_resolucion`).
- [ ] **T-213.3** Validar que `comentario_resolucion` es obligatorio cuando `estado == "rechazada"`.
- [ ] **T-213.4** Confirmar explícitamente (a nivel de lógica, sin efectos secundarios) que aprobar una solicitud NO crea un lote ni modifica stock — solo actualiza el estado.
- [ ] **T-213.5** Disparar notificación al `usuario_solicitante` con el resultado, vía `NotificationService` + `NotificacionApp`.
- [ ] **T-213.6** Registrar en auditoría la resolución (quién, cuándo, resultado).

### HU-214: Vista global de solicitudes (Administrador)

- [ ] **T-214.1** Endpoint `GET /inventario/solicitudes` (sin filtro de estado por defecto) restringido a `ver_reportes_globales` o `gestionar_usuarios` equivalente de Administrador.
- [ ] **T-214.2** Soporte de filtros por `usuario_id`, `material_id`, `motivo`, `estado`.
- [ ] **T-214.3** Confirmar que este endpoint es de solo lectura (no permite transición de estado desde aquí, eso es exclusivo de T-213.2).

### 🧪 T-211.T — Test de la Épica 2.E
- [ ] Suite de tests: creación de solicitud con sugerencia automática de motivo, notificación disparada a los roles correctos, edición y cancelación solo por el dueño y solo en estado pendiente, bloqueo de edición fuera de esos casos, resolución con comentario obligatorio en rechazo, confirmación de que aprobar no altera stock, notificación de resultado al solicitante, filtros del endpoint de vista global.

---

## ÉPICA 2.F — Alertas de Stock Bajo y Vencimiento

### HU-215: Revisión periódica y envío de alertas

- [ ] **T-215.1** Crear tarea periódica de Celery (`revisar_alertas_inventario`) programada diariamente vía Celery beat.
- [ ] **T-215.2** Implementar función `materiales_bajo_minimo()` que compara `stock_total_disponible(material)` contra `material.stock_minimo` para todos los materiales activos.
- [ ] **T-215.3** Implementar función `lotes_con_alerta_vencimiento_activa()` que filtra lotes donde `hoy >= fecha_alerta_vencimiento` y `cantidad_disponible > 0`.
- [ ] **T-215.4** Armar el mensaje de alerta (agrupado, no un mensaje por cada material individual, para no saturar) y enviarlo vía `NotificationService` a los usuarios con rol Administrador y GestorInventario.
- [ ] **T-215.5** Crear también el registro correspondiente en `NotificacionApp` (T-211.6) para que la alerta quede visible dentro de la app además del canal externo.
- [ ] **T-215.6** Evitar reenvío duplicado del mismo material/lote el mismo día (marca de "ya notificado hoy" con expiración diaria).

### HU-216: Toggle de alertas de inventario

- [ ] **T-216.1** Agregar campo `alertas_inventario_activas` (booleano, default true) al modelo `ConfiguracionSistema` ya creado en el Módulo 1.
- [ ] **T-216.2** Endpoint `PATCH /admin/config/alertas-inventario` restringido a Administrador/Superadmin.
- [ ] **T-216.3** Modificar T-215.4 para que, si `alertas_inventario_activas == false`, la tarea siga ejecutando el cálculo (T-215.2, T-215.3) pero omita el paso de envío de notificaciones.
- [ ] **T-216.4** Confirmar que el dashboard y reportes (Épicas 2.G y 2.H) siguen leyendo estos cálculos sin importar el estado del toggle.

### 🧪 T-215.T — Test de la Épica 2.F
- [ ] Suite de tests: detección correcta de materiales bajo mínimo y lotes con alerta activa, envío agrupado sin duplicados el mismo día, respeto del toggle (cálculo sigue corriendo, envío se detiene), notificación llega tanto a Administrador como GestorInventario.

---

## ÉPICA 2.G — Reportes en PDF (bajo demanda)

### HU-217: Generación de PDF por fecha o rango

- [ ] **T-217.1** Endpoint `POST /inventario/reportes/pdf` restringido a Administrador/Superadmin, recibe `fecha_inicio`, `fecha_fin` (puede ser fecha única si ambas coinciden).
- [ ] **T-217.2** Función de agregación que recolecta: stock actual con estado, movimientos del período (entradas/salidas/ajustes) contados y diferenciados por día, lotes por vencer dentro del período, solicitudes pendientes al momento de generar, resumen de gasto del período.
- [ ] **T-217.3** Generar el archivo PDF usando WeasyPrint a partir de una plantilla HTML/CSS dedicada.
- [ ] **T-217.4** Guardar el PDF generado en almacenamiento temporal/persistente y devolver una URL o el archivo descargable en la respuesta.
- [ ] **T-217.5** Registrar en auditoría la generación del reporte (quién, cuándo, rango solicitado).

### HU-218: Filtro de PDF por usuario específico

- [ ] **T-218.1** Agregar parámetro opcional `usuario_id` al endpoint de T-217.1.
- [ ] **T-218.2** Modificar la función de agregación (T-217.2) para que, si viene `usuario_id`, filtre movimientos y solicitudes exclusivamente donde ese usuario participó.
- [ ] **T-218.3** Mantener la misma estructura/plantilla del PDF general, adaptando el título/encabezado para indicar que es un reporte filtrado por usuario.

### HU-219: Entrega dual (descarga + mensajería)

- [ ] **T-219.1** Confirmar que el endpoint de generación (T-217.1) siempre deja el archivo disponible para descarga inmediata.
- [ ] **T-219.2** Endpoint adicional `POST /inventario/reportes/{id}/enviar-por-mensajeria` que toma un reporte ya generado y lo envía como documento adjunto vía `NotificationService` (Telegram soporta `sendDocument`; dejar interfaz lista para WhatsApp/Twilio con media URL).
- [ ] **T-219.3** Validar que ambos canales entregan exactamente el mismo archivo (mismo hash/referencia, no una regeneración distinta).

### 🧪 T-217.T — Test de la Épica 2.G
- [ ] Suite de tests: generación de PDF con rango de un solo día y con rango de varios días, conteo correcto de movimientos diferenciados por día, filtro por usuario específico devolviendo solo su actividad, envío del mismo archivo por descarga y por mensajería, restricción de acceso solo a Administrador/Superadmin.

---

## ÉPICA 2.H — Dashboard y Reporte de Gastos

### HU-220: Dashboard de materiales más usados

- [ ] **T-220.1** Endpoint `GET /inventario/dashboard/mas-usados` restringido a Administrador (y Superadmin como acceso secundario, no en su vista principal — validar a nivel de permisos, no de ruta distinta).
- [ ] **T-220.2** Parámetros: `fecha_inicio`, `fecha_fin` (default: últimos 30 días si no se especifican), `area_id`, `categoria_id` opcionales.
- [ ] **T-220.3** Agregación por `SUM(cantidad)` de `MovimientoSalida` agrupado por material, ordenado descendente, dentro del rango y filtros dados.

### HU-221: Panel de materiales con solicitud preventiva

- [ ] **T-221.1** Endpoint `GET /inventario/dashboard/reposicion-preventiva` restringido a Administrador.
- [ ] **T-221.2** Agregación de `SolicitudMaterial` filtrando `motivo = "reposicion_preventiva"`, agrupado por material con conteo de frecuencia.
- [ ] **T-221.3** Confirmar que esta consulta es completamente independiente del endpoint de T-220.1 (no se combinan en una sola respuesta).

### HU-222: Reporte de gastos agrupado

- [ ] **T-222.1** Endpoint `GET /inventario/reportes/gastos` restringido a Administrador, con parámetro de rango de fechas libre.
- [ ] **T-222.2** Vista de resumen por categoría: `SUM(costo)` de lotes ingresados en el período, agrupado por `categoria_id`, incluyendo conteo de lotes con `costo_registrado = false` dentro de ese grupo.
- [ ] **T-222.3** Vista de detalle por material: mismo cálculo pero agrupado por `material_id`.
- [ ] **T-222.4** Calcular y devolver el porcentaje global de ingresos del período sin costo registrado, para el aviso de "costo incompleto" en el frontend.

### 🧪 T-220.T — Test de la Épica 2.H
- [ ] Suite de tests: cálculo correcto del ranking de más usados con filtros de fecha/área/categoría, panel de reposición preventiva aislado del ranking principal, agregación de gastos por categoría y por material, cálculo correcto del porcentaje de costo incompleto, restricción de acceso exclusiva a Administrador.

---

## Resumen de cobertura de testing por épica

| Épica | Tarea de test | Enfoque principal |
|---|---|---|
| 2.A | T-201.T | Catálogo (áreas/categorías/materiales), búsqueda y filtrado |
| 2.B | T-205.T | Ingreso de lotes, costo opcional, validación de fechas |
| 2.C | T-207.T | Salida FEFO, concurrencia, bloqueo de sobregiro |
| 2.D | T-209.T | Ajustes trazables, inmutabilidad del historial |
| 2.E | T-211.T | Ciclo completo de solicitudes, permisos, notificaciones |
| 2.F | T-215.T | Alertas automáticas, toggle de envío |
| 2.G | T-217.T | Generación y entrega dual de PDF bajo demanda |
| 2.H | T-220.T | Dashboard, panel preventivo, reporte de gastos |
