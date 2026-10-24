# Módulo 3 — Respaldo de Base de Datos
## Historias de Usuario + Tareas Backend (Scrumban)

> Continúa numeración: Historias desde **HU-301**, tareas desde **T-301**.

---

## ÉPICA 3.A — Backup Automático y Manual vía Telegram

### HU-301: Como sistema, debo generar y enviar un respaldo diario de la base de datos al Superadmin por Telegram, para tener una copia de seguridad externa sin depender del almacenamiento del servidor.

**Criterios de aceptación:**
- Tarea programada diaria (Celery beat), horario configurable a nivel de código/config (no requiere pantalla propia de UI por ahora).
- El dump se genera comprimido y nombrado con fecha (`backup_ceos_YYYY-MM-DD.sql.gz`).
- Se envía como documento adjunto vía `NotificationService`, directo al chat_id del Superadmin.
- Tras la confirmación de envío exitoso, el archivo se borra del disco del servidor.
- Si el envío falla, el archivo temporal se conserva hasta un reintento posterior (no se pierde el backup del día), y se reintenta un número limitado de veces antes de marcar el intento como fallido.
- Se registra en auditoría cada ejecución (éxito o fallo, timestamp, tamaño del archivo).

**Tareas técnicas:**
- [ ] **T-301.1** Crear tarea de Celery `generar_backup_diario` programada vía Celery beat.
- [ ] **T-301.2** Implementar la generación del dump (`pg_dump`) desde Python/Celery, con compresión (`gzip`).
- [ ] **T-301.3** Nombrar el archivo con el patrón `backup_ceos_YYYY-MM-DD.sql.gz`.
- [ ] **T-301.4** Integrar el envío del archivo generado con `NotificationService`, extendiendo la interfaz para soportar envío de documentos/adjuntos (reutilizar lo ya construido en T-219.2 para PDFs, generalizándolo si aplica).
- [ ] **T-301.5** Implementar borrado del archivo del disco solo tras confirmación de envío exitoso (verificar respuesta de la API de Telegram antes de borrar).
- [ ] **T-301.6** Implementar lógica de reintento (ej. 3 intentos con backoff) si el envío falla, conservando el archivo temporal mientras tanto.
- [ ] **T-301.7** Crear modelo `RegistroBackup` (fecha, estado [`exitoso`/`fallido`], tamaño_archivo, cantidad_intentos, timestamp) para trazabilidad, separado del log genérico de auditoría.
- [ ] **T-301.8** Manejar el caso de error irrecuperable (ej. falla de red persistente): notificar al Superadmin por un canal alterno si existe, o dejar constancia clara en `RegistroBackup` para revisión manual.

---

### HU-302: Como Superadmin, quiero poder generar un backup manual en cualquier momento, para tener una copia extra antes de cambios riesgosos (migraciones, despliegues).

**Criterios de aceptación:**
- Acción disponible solo para el rol Superadmin.
- Ejecuta exactamente el mismo flujo que el backup automático (generar, comprimir, enviar por Telegram, borrar del servidor).
- La respuesta del endpoint confirma el resultado (éxito/fallo) sin que el Superadmin tenga que esperar la ejecución de la tarea programada.
- Queda registrado en `RegistroBackup` igual que los automáticos, diferenciando el origen (`automatico` / `manual`).

**Tareas técnicas:**
- [ ] **T-302.1** Endpoint `POST /admin/backup/generar` restringido exclusivamente al rol Superadmin (validación explícita de `es_superadmin`, no solo un permiso genérico).
- [ ] **T-302.2** Refactorizar la lógica de T-301.2 a T-301.6 en una función reutilizable (`ejecutar_backup(origen: "automatico" | "manual")`) invocada tanto por la tarea programada como por este endpoint.
- [ ] **T-302.3** Agregar campo `origen` al modelo `RegistroBackup` (T-301.7).
- [ ] **T-302.4** Ejecutar la función de forma asíncrona (vía Celery task disparada on-demand) para no bloquear la respuesta HTTP mientras se genera el dump.
- [ ] **T-302.5** Endpoint `GET /admin/backup/estado/{tarea_id}` o mecanismo equivalente para que el Superadmin pueda consultar si el backup manual ya terminó y su resultado.

---

### HU-303: Como Superadmin, quiero ver un historial de los backups realizados (automáticos y manuales), para confirmar que se están ejecutando correctamente sin depender solo de revisar el chat de Telegram.

**Criterios de aceptación:**
- Listado de `RegistroBackup` con fecha, origen, estado, tamaño e intentos.
- Filtrable por rango de fechas y por estado (para detectar rápido si hubo fallos).
- Solo accesible para Superadmin.

**Tareas técnicas:**
- [ ] **T-303.1** Endpoint `GET /admin/backup/historial` restringido a Superadmin, con filtros por fecha y estado.
- [ ] **T-303.2** Paginación estándar del listado (mismo patrón usado en otros historiales del sistema).

---

### 🧪 T-301.T — Test de la Épica 3.A
- [ ] Suite de tests: generación correcta del dump comprimido con nomenclatura esperada, envío exitoso vía Telegram y borrado posterior del archivo, comportamiento ante fallo de envío (conservación del archivo + reintentos), ejecución manual restringida solo a Superadmin, registro correcto en `RegistroBackup` diferenciando origen automático/manual, filtros del endpoint de historial.

---

## Resumen para el tablero

| Épica | # Historias | Prioridad sugerida |
|---|---|---|
| 3.A Backup Automático y Manual | 3 (HU-301 a 303) | Alta — protege la integridad de todo lo ya construido |

**Orden de desarrollo recomendado:** HU-301 (automático) → HU-302 (manual, reutiliza la lógica) → HU-303 (historial, depende de que ya existan registros generados por las dos anteriores).

---

## ✅ Cierre del Sistema de Gestión de Inventario Móvil (CEOS)

Con este módulo, quedan cerrados de punta a punta:

| Módulo | Historias | Estado |
|---|---|---|
| 1. Usuarios y Roles | 15 (HU-101 a 115) | ✅ Completo |
| 2. Inventario de Materiales | 22 (HU-201 a 222) | ✅ Completo |
| 3. Respaldo de Base de Datos | 3 (HU-301 a 303) | ✅ Completo |

**Total: 40 historias de usuario**, todas con criterios de aceptación y tareas backend atómicas listas para tablero Scrumban.

Quedan pendientes como **plus futuro** (fuera del alcance actual): Módulo de Servicios/Tratamientos, Historial Clínico de Pacientes, e Integración Biométrica (cancelada por ahora). La página web de agendamiento de pacientes queda como el siguiente gran bloque a especificar.
