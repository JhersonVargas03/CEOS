# Módulo 2 — Inventario de Materiales
## Historias de Usuario (Scrumban)

> Formato: Épica → Historia de Usuario → Criterios de aceptación.
> Continúa la numeración del Módulo 1 (HU-101 a HU-115) a partir de **HU-201**.

---

## ÉPICA 2.A — Catálogo de Materiales (Áreas, Categorías, Materiales)

### HU-201: Como Administrador o GestorInventario, quiero crear y editar Áreas (Odontología/Estética), para clasificar los materiales según a qué parte de la clínica pertenecen.
**Criterios de aceptación:**
- Catálogo de Áreas editable, no fijo en el código (mismo patrón que roles del Módulo 1).
- Se pueden crear nuevas áreas a futuro sin requerir cambios de código.
- No se puede eliminar un área que ya tiene materiales asociados (solo desactivar).

### HU-202: Como Administrador o GestorInventario, quiero crear y editar Categorías de material (guantes, anestesia, tubos, etc.), para organizar y filtrar el inventario.
**Criterios de aceptación:**
- Catálogo de categorías editable, independiente del catálogo de Áreas.
- No se puede eliminar una categoría que ya tiene materiales asociados (solo desactivar).

### HU-203: Como Administrador o GestorInventario, quiero registrar un material nuevo en el catálogo, para poder empezar a controlar su stock.
**Criterios de aceptación:**
- Formulario: nombre, área, categoría, unidad de medida, stock mínimo (default 5, editable).
- No se puede crear un material con nombre duplicado dentro de la misma área+categoría.
- El material queda disponible de inmediato para registrar ingresos.

### HU-204: Como cualquier usuario con acceso al inventario, quiero buscar materiales por nombre y filtrarlos por área/categoría, para encontrar lo que necesito rápido.
**Criterios de aceptación:**
- Búsqueda por texto libre sobre el nombre del material.
- Filtros combinables por área y por categoría.
- Resultados muestran stock actual y estado (normal / bajo mínimo / con lotes por vencer).

---

## ÉPICA 2.B — Ingreso de Lotes (Entradas)

### HU-205: Como GestorInventario, quiero registrar el ingreso de un lote de material, para sumar stock nuevo con su propia fecha de caducidad.
**Criterios de aceptación:**
- Formulario: material, cantidad, fecha de ingreso, fecha de caducidad, fecha de alerta de vencimiento, costo (opcional).
- Cada ingreso crea un lote independiente, no se suma directo a un stock genérico sin trazabilidad.
- Si no se ingresa costo, el lote queda marcado internamente como "sin costo registrado" para efectos de reportes.
- Se registra automáticamente quién hizo el ingreso y cuándo (auditoría).

### HU-206: Como Administrador o GestorInventario, quiero ver el listado de lotes de un material específico, para saber exactamente qué cantidades hay y cuándo vence cada una.
**Criterios de aceptación:**
- Lista de lotes ordenada por fecha de caducidad (más próximo primero).
- Cada lote muestra cantidad disponible actual (descontando salidas ya aplicadas).
- Indicador visual para lotes ya alcanzaron su fecha de alerta de vencimiento.

---

## ÉPICA 2.C — Salidas de Material (FEFO)

### HU-207: Como usuario con permiso de registrar salidas, quiero descontar material del inventario, para reflejar lo que efectivamente se usó.
**Criterios de aceptación:**
- El usuario elige material y cantidad; el sistema decide automáticamente de qué lote(s) descontar según FEFO (el que vence antes, sale primero).
- Si la cantidad solicitada supera lo disponible en el lote más próximo a vencer, el sistema puede descontar de más de un lote en orden de vencimiento hasta completar la cantidad.
- Queda registrado quién hizo la salida, cuándo, cantidad y de qué lote(s).

### HU-208: Como sistema, debo impedir que se registre una salida mayor al stock total disponible del material.
**Criterios de aceptación:**
- Si la cantidad solicitada supera el stock total disponible (sumando todos los lotes), la salida se rechaza y no se guarda ningún movimiento.
- El mensaje de error es claro y accionable: indica cuánto hay disponible y cuánto se intentó sacar.
- Si el usuario tiene permiso de hacer ajustes de inventario, el mensaje incluye acceso directo a esa función.
- Si el usuario NO tiene permiso de ajustar, el mensaje sugiere avisar al encargado de inventario, sin mostrar accesos que no puede usar.

---

## ÉPICA 2.D — Ajustes de Inventario

### HU-209: Como Administrador o GestorInventario, quiero hacer un ajuste manual de stock de un lote, para corregir diferencias entre el inventario físico y el digital.
**Criterios de aceptación:**
- El ajuste requiere un motivo obligatorio (texto libre o catálogo de motivos frecuentes: conteo físico, material dañado, error de carga anterior, etc.).
- El ajuste se aplica de inmediato, sin necesidad de aprobación de otra persona.
- No se permite editar directamente la cantidad de un lote existente — todo cambio pasa por esta función de ajuste.
- Queda registrado: usuario, lote afectado, cantidad anterior, cantidad nueva, motivo, timestamp.

### HU-210: Como Administrador o GestorInventario, quiero ver el historial de ajustes de inventario en una sección separada, para diferenciarlos de los movimientos normales de entrada/salida.
**Criterios de aceptación:**
- Sección dedicada exclusivamente a ajustes (no mezclada con el historial de entradas/salidas).
- Filtrable por material, usuario que hizo el ajuste, y rango de fechas.
- Los registros son inmutables (no se editan ni eliminan una vez creados).

---

## ÉPICA 2.E — Solicitudes de Material

### HU-211: Como Doctor (u otro rol con permiso de solicitar), quiero pedir material indicando el motivo, para avisar que necesito reposición.
**Criterios de aceptación:**
- Formulario: material, cantidad, motivo (`sin_stock` / `reposicion_preventiva`), comentario opcional.
- Si el stock del material está en 0, el sistema puede sugerir automáticamente el motivo `sin_stock`, pero el usuario puede ajustarlo.
- Al enviarse, la solicitud queda en estado `pendiente`.
- GestorInventario y Administrador reciben notificación de la solicitud nueva, por el canal de mensajería activo y dentro de la app.

### HU-212: Como Doctor, quiero editar o cancelar una solicitud mientras siga pendiente, para corregir errores sin tener que esperar a que la rechacen.
**Criterios de aceptación:**
- Solo el usuario que creó la solicitud puede editarla o cancelarla.
- Solo es posible mientras el estado siga siendo `pendiente` — una vez resuelta (aprobada/rechazada), ya no se puede editar ni cancelar.
- La edición permite cambiar cantidad, motivo y comentario.
- La cancelación cambia el estado a `cancelada` (no se elimina el registro, se conserva para trazabilidad).

### HU-213: Como GestorInventario, quiero ver el listado de solicitudes pendientes y resolverlas (aprobar/rechazar), para gestionar la reposición de material.
**Criterios de aceptación:**
- Listado de solicitudes pendientes, con motivo visible para ayudar a priorizar.
- Al aprobar o rechazar, se registra quién resolvió y cuándo.
- Si se rechaza, se requiere un comentario obligatorio explicando el motivo.
- Aprobar una solicitud no mueve stock ni crea un lote automáticamente — es solo una señal de "hay que comprar"; el ingreso real se registra después como un lote normal (Épica 2.B).
- El solicitante recibe notificación del resultado, por canal de mensajería activo y dentro de la app.

### HU-214: Como Administrador, quiero ver el historial completo de solicitudes (de todos los usuarios), para tener visibilidad total aunque no las resuelva yo.
**Criterios de aceptación:**
- Vista de solo lectura sobre todas las solicitudes, sin importar el estado.
- Filtrable por usuario, material, motivo y estado.

---

## ÉPICA 2.F — Alertas de Stock Bajo y Vencimiento

### HU-215: Como sistema, debo revisar periódicamente qué materiales están bajo su stock mínimo o con lotes próximos a vencer, para notificar antes de que sea un problema.
**Criterios de aceptación:**
- Revisión automática programada (tarea periódica, ej. diaria).
- Stock bajo: se compara el total disponible del material contra su stock mínimo configurado.
- Vencimiento próximo: se evalúa la fecha de alerta configurada en cada lote individualmente.
- Las alertas se envían tanto a Administrador como a GestorInventario, por el canal de mensajería activo y dentro de la app.

### HU-216: Como Administrador o Superadmin, quiero poder apagar el envío de alertas de inventario sin desactivar su cálculo interno, para tener flexibilidad sin perder los datos.
**Criterios de aceptación:**
- Switch de configuración accesible solo a Administrador/Superadmin.
- Con el switch apagado, el sistema sigue calculando qué está bajo mínimo o por vencer (dashboard y reportes no se ven afectados).
- Con el switch apagado, simplemente no se envían las notificaciones por el canal de mensajería ni dentro de la app.

---

## ÉPICA 2.G — Reportes en PDF (bajo demanda)

### HU-217: Como Administrador o Superadmin, quiero generar un PDF de inventario para un día o rango de días específico, para revisar la actividad de un período concreto.
**Criterios de aceptación:**
- Selector de fecha única o rango de fechas.
- El PDF incluye: stock actual con alertas visuales, movimientos del período (entradas/salidas/ajustes) con su conteo diferenciado por día, lotes próximos a vencer, solicitudes pendientes, y resumen de gasto del período.
- Generación 100% bajo demanda — no hay envío automático programado.

### HU-218: Como Administrador o Superadmin, quiero generar el PDF filtrado por un usuario específico, para revisar la actividad de esa persona en particular.
**Criterios de aceptación:**
- Al elegir un usuario, el PDF solo incluye movimientos donde ese usuario participó (entradas, salidas, ajustes, solicitudes resueltas).
- Mantiene el mismo formato y secciones que el PDF general, adaptado al alcance filtrado.

### HU-219: Como Administrador o Superadmin, quiero recibir el PDF generado tanto por descarga en la app como por el canal de mensajería activo, para tener una doble confirmación de que se generó correctamente.
**Criterios de aceptación:**
- Tras generar el reporte, queda disponible para descarga inmediata dentro de la app.
- El usuario puede además solicitar el envío del mismo archivo por el canal de mensajería activo (Telegram/WhatsApp).
- Ambas vías entregan exactamente el mismo archivo.

---

## ÉPICA 2.H — Dashboard y Reporte de Gastos

### HU-220: Como Administrador (y Superadmin, fuera de la vista principal), quiero ver un dashboard de materiales más usados, para identificar patrones de consumo.
**Criterios de aceptación:**
- Ranking de materiales por cantidad de salidas, con período por defecto (ej. últimos 30 días) y selector de rango de fechas libre.
- Filtrable por área y por categoría.
- No visible para roles Doctor/GestorInventario (solo Administrador y, si aplica, Superadmin de forma secundaria).

### HU-221: Como Administrador, quiero ver un panel separado de materiales con solicitudes de reposición preventiva, para identificar cuáles casi no se usan pero igual generan pedidos anticipados.
**Criterios de aceptación:**
- Panel independiente del ranking de más usados (no mezclado).
- Lista materiales cuyas solicitudes recientes tienen motivo `reposicion_preventiva`, con la frecuencia de este tipo de solicitud por material.

### HU-222: Como Administrador, quiero consultar un reporte de gastos agrupado por categoría y por material, para entender en qué se está invirtiendo el presupuesto de insumos.
**Criterios de aceptación:**
- Reporte consultable dentro de la app bajo demanda (no forma parte del PDF diario programado, ya que este módulo no tiene envíos automáticos de reportes completos).
- Dos vistas disponibles: resumen por categoría y detalle por material.
- Selector de rango de fechas libre.
- Los materiales/lotes sin costo registrado se marcan con una etiqueta de advertencia ("⚠ costo incompleto"), y el reporte muestra el porcentaje de ingresos del período sin costo registrado, para dejar claro que el total mostrado puede ser menor al gasto real.

---

## Resumen para el tablero

| Épica | # Historias | Prioridad sugerida |
|---|---|---|
| 2.A Catálogo de Materiales | 4 (HU-201 a 204) | Muy alta — bloqueante, define el modelo base |
| 2.B Ingreso de Lotes | 2 (HU-205 a 206) | Muy alta |
| 2.C Salidas (FEFO) | 2 (HU-207 a 208) | Muy alta |
| 2.D Ajustes de Inventario | 2 (HU-209 a 210) | Alta |
| 2.E Solicitudes de Material | 4 (HU-211 a 214) | Alta |
| 2.F Alertas | 2 (HU-215 a 216) | Alta — reutiliza infraestructura del Módulo 1 |
| 2.G Reportes PDF | 3 (HU-217 a 219) | Media-alta |
| 2.H Dashboard y Gastos | 3 (HU-220 a 222) | Media |

**Orden de desarrollo recomendado:** 2.A (catálogo) → 2.B (entradas) → 2.C (salidas/FEFO) → 2.D (ajustes) → 2.E (solicitudes) → 2.F (alertas, reutilizando `NotificationService` del Módulo 1) → 2.G (reportes PDF) → 2.H (dashboard y gastos, al final porque depende de tener datos históricos ya generados por el resto del módulo).
