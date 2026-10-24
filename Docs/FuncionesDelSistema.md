🔴 FUNCIONES PRINCIPALES (core del sistema)

1. Gestión de Usuarios y Roles

1.1 Registro/login de usuarios
1.2 Roles: Administrador, Registrador (entrada/salida), Solicitante
1.3 Permisos por endpoint según rol
1.4 Vinculación de canal de notificación (Telegram chat_id / número WhatsApp)

2. Inventario de Materiales

2.1 Alta de material (nombre, categoría, fecha ingreso, fecha caducidad, stock)
2.2 Categorías de material (tubos, insumos generales, etc.)
2.3 Registro de salida (quién saca, cuánto, para qué)
2.4 Stock mínimo configurable (default 5) + fecha de alerta de vencimiento configurable
2.5 Inventario individual por usuario + inventario general acumulado
2.6 Historial de movimientos (auditoría: quién movió qué y cuándo)

3. Categorías de Servicio: Odontología / Estética

3.1 Catálogo de servicios por categoría (nombre, duración, profesional habilitado)
3.2 Vínculo servicio → materiales consumidos (descuento automático de inventario)
3.3 Reportes segmentados por categoría (consumo, ingresos, frecuencia)

4. Sistema de Alertas y Notificaciones

4.1 Alerta de stock bajo (umbral mínimo alcanzado)
4.2 Alerta de vencimiento próximo (según fecha configurada)
4.3 Motor de envío abstracto (WhatsApp/Telegram/Email)
4.4 Bot de Telegram activo desde el día 1

5. Reportes

5.1 Reporte diario en PDF (stock, movimientos, gastos)
5.2 Envío automático programado a hora específica
5.3 Dashboard de materiales más usados/salidos
🟡 FUNCIONES SECUNDARIAS (completan el flujo operativo)

6. Solicitud de Compra / Reposición

6.1 Usuario solicita material sin stock
6.2 Bandeja de solicitudes para administrador (aprobar/rechazar)
6.3 Notificación de solicitud pendiente

7. Control de Gastos

7.1 Registro de dinero gastado en material
7.2 Vínculo gasto ↔ ingreso de material
7.3 Reporte de gasto acumulado (por período, por categoría)

8. Página Web de Agendamiento

8.1 Pacientes agendan citas
8.2 Pacientes reprograman/cancelan
8.3 Vista de disponibilidad por profesional/categoría (odontología/estética)

9. Historial Clínico de Pacientes

9.1 Definir estrategia: digital puro vs. híbrido con hojas físicas (pendiente investigar flujo actual)
9.2 Ficha de paciente (datos, tratamientos, servicios recibidos)
9.3 Vínculo historial ↔ servicios de la categoría 3
🟢 SUBFUNCIONES / FUTURO (valor agregado, no bloqueantes)

10. Respaldo de Base de Datos

10.1 Backup automático programado

11. Integración Biométrico

11.1 Investigar si el equipo puede emitir señal/API hacia el sistema (marcaje de asistencia)

12. Módulo de Promociones (POSIBLE OPCIÓN, descartado por ahora)

12.1 Captura de promociones de venta
12.2 Página de odontólogos con ofertas registradas