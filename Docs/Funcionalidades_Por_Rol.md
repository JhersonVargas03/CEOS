# 📋 Guía y Matriz de Funcionalidades por Rol — Sistema CEOS

> **Propósito:** Documento de referencia interactivo para validar y probar el comportamiento del sistema desde la perspectiva de cada rol de usuario. Utiliza este documento para verificar qué acciones, pantallas y restricciones debe tener cada perfil en la aplicación móvil y backend.

---

## 📑 Índice
1. [Resumen de Roles y Usuarios de Prueba](#1-resumen-de-roles-y-usuarios-de-prueba)
2. [Matriz General de Permisos vs Roles (RBAC)](#2-matriz-general-de-permisos-vs-roles-rbac)
3. [Rol: Superadmin 👑](#3-rol-superadmin-)
4. [Rol: Administrador 🏢](#4-rol-administrador-)
5. [Rol: Gestor de Inventario 📦](#5-rol-gestor-de-inventario-)
6. [Rol: Doctor (Personal Médico/Asistencial) 🩺](#6-rol-doctor-personal-médicoasistencial-)
7. [Estado: Usuario Inactivo / Restringido 🚫](#7-estado-usuario-inactivo--restringido-)
8. [Flujos de Prueba Cruzados (Interacción entre Roles)](#8-flujos-de-prueba-cruzados-interacción-entre-roles)
9. [Checklist Interactivo de Validación](#9-checklist-interactivo-de-validación)

---

## 1. Resumen de Roles y Usuarios de Prueba

En la base de datos se encuentran configurados los 4 roles canónicos de fábrica del sistema:

| Rol | Icono | Descripción Principal | Usuario de Prueba en BD |
|---|:---:|---|---|
| **Superadmin** | 👑 | Control total técnico y operativo del sistema, servidor, roles y auditoría. | `admin` / `jherkis` |
| **Administrador** | 🏢 | Gestión operativa de la clínica: usuarios, catálogo, reportes y aprobación. | `jherkisad` |
| **GestorInventario** | 📦 | Gestión física del almacén: catálogo, entradas de lotes, salidas, ajustes y resolución. | `jherkisin` |
| **Doctor** | 🩺 | Personal de salud: consumo FEFO de insumos para pacientes y solicitudes de reposición. | `jherkisdoctor` |

> [!TIP]
> **Cambio rápido de contraseña para pruebas:** Si necesitas reestablecer la contraseña de cualquier usuario de prueba para ingresar desde la app, puedes ejecutar en la terminal del backend:
> ```bash
> /home/v4/Ceos/Backend/.venv/bin/python manage.py changepassword <nombre_usuario>
> ```

---

## 2. Matriz General de Permisos vs Roles (RBAC)

El sistema cuenta con **12 permisos atómicos** que determinan qué opciones del menú, botones y endpoints están disponibles:

| Código de Permiso | Nombre Funcional | Superadmin | Administrador | GestorInventario | Doctor |
|---|---|:---:|:---:|:---:|:---:|
| `gestionar_roles` | Gestión de Roles Dinámicos | ✅ | ❌ | ❌ | ❌ |
| `gestionar_usuarios` | Gestión de Usuarios y Accesos | ✅ | ✅ | ❌ | ❌ |
| `gestionar_catalogo_inventario` | Crear/Editar Áreas, Categorías y Materiales | ✅ | ✅ | ✅ | ❌ |
| `crear_material` | Dar de alta nuevos materiales en catálogo | ✅ | ✅ | ✅ | ❌ |
| `registrar_entrada` | Registrar lotes de ingreso de material | ✅ | ✅ | ✅ | ❌ |
| `registrar_salida` | Registrar salidas con descuento FEFO | ✅ | ✅ | ✅ | ✅ |
| `ajustar_inventario` | Ajustes manuales por merma/conteo | ✅ | ✅ | ✅ | ❌ |
| `solicitar_material` | Crear solicitudes de compra/reposición | ✅ | ✅ | ✅ | ✅ |
| `aprobar_solicitud` | Aprobar o rechazar solicitudes de material | ✅ | ✅ | ✅ | ❌ |
| `ver_reportes_globales` | Dashboards globales y reportes PDF | ✅ | ✅ | ❌ | ❌ |
| `ver_mi_historial` | Consultar historial de movimientos propios | ✅ | ✅ | ✅ | ✅ |
| `ver_mis_reportes` | Consultar métricas y solicitudes propias | ✅ | ✅ | ✅ | ✅ |

---

## 3. Rol: Superadmin 👑

Es el rol con máxima jerarquía. Dispone de acceso irrestricto tanto a la administración técnica de la plataforma como a la operación del inventario.

### 🌟 Qué DEBE poder ver y hacer:
1. **Acceso al Panel de Administración Completo (`/admin`):**
   - **Gestión de Roles (`/admin/roles`):**
     - Ver lista de roles de fábrica y personalizados. 
     - Crear nuevos roles dinámicos seleccionando permisos específicos.
     - Editar nombres y permisos de roles personalizados.
     - Eliminar roles creados (los roles de fábrica están protegidos contra eliminación).
   - **Gestión de Usuarios (`/admin/usuarios`):**
     - Crear nuevos usuarios con credenciales temporales.
     - Asignar múltiples roles a un usuario.
     - Activar o desactivar usuarios (suspensión inmediata de sesión).
     - Forzar reseteo de contraseña y desvincular Telegram/dispositivo.
   - **Copias de Seguridad / Backups (`/admin/backups`):**
     - Generar backup manual inmediato de la base de datos (cifrado y empaquetado).
     - Ver historial de backups generados con fecha, peso y estado.
     - Descargar o enviar backup generado al canal de Telegram configurado.
   - **Configuración del Sistema (`/admin/configuracion`):**
     - Definir el canal de mensajería prioritario (**Telegram** o **WhatsApp**).
     - Configurar credenciales del Bot de Telegram (token, chat ID).
     - Configurar parámetros de alertas globales de stock mínimo.
   - **Logs de Auditoría (`/admin/auditoria`):**
     - Consultar registro inmutable de acciones críticas (quién inició sesión, quién modificó stock, qué IP se conectó, intentos fallidos).

2. **Operación Completa de Inventario:**
   - Crear, editar y eliminar **Áreas** (con catálogo ampliado de íconos temáticos: labios, botiquín, dientes, jeringas, etc.).
   - Crear y editar **Categorías** vinculadas a áreas.
   - Crear y editar **Materiales** (unidad de medida, stock mínimo, días de alerta).
   - Registrar **Entradas de Lote** (con o sin fecha de vencimiento, lote autogenerado si se deja en blanco).
   - Registrar **Salidas FEFO** y **Ajustes manuales de stock**.
   - Aprobar y rechazar solicitudes en **Resolver Solicitudes**.
   - Generar **Reportes PDF** y enviarlos por mensajería al instante.
   - Visualizar **Dashboard de Reposición Preventiva** y materiales más usados.

### 🚫 Qué NO debe permitir el sistema:
- No se puede eliminar el rol `Superadmin` ni los roles con la bandera `es_de_fabrica = True`.
- No puede auto-desactivarse a sí mismo para evitar el bloqueo total del sistema.

---

## 4. Rol: Administrador 🏢

Es el perfil directivo u operativo de la clínica. Administra al personal y supervisa los movimientos financieros y de stock sin manipular la configuración de bajo nivel del servidor.

### 🌟 Qué DEBE poder ver y hacer:
1. **Gestión de Usuarios:**
   - Crear cuentas para médicos, asistentes o gestores de almacén.
   - Asignar roles existentes a los usuarios.
   - Activar y desactivar cuentas de colaboradores.
   - Resetear contraseñas temporales a usuarios que olvidaron su clave.
2. **Supervisión y Aprobación de Inventario:**
   - Bandeja **Resolver Solicitudes (`/inventario/resolver-solicitudes`):**
     - Ver solicitudes pendientes emitidas por Doctores.
     - Aprobar solicitudes indicando comentarios o cantidad aprobada.
     - Rechazar solicitudes con motivo justificado.
   - Acceso a **Todas las Solicitudes (`/inventario/todas-solicitudes`):**
     - Histórico global con filtros por estado (Pendiente, Aprobada, Rechazada).
3. **Catálogo y Operaciones de Stock:**
   - Alta y edición de Áreas, Categorías y Materiales.
   - Registro de entradas de lotes y ajustes manuales.
   - Registro de salidas con trazabilidad de motivo.
4. **Reportes y Métricas:**
   - Generación de **Reporte PDF consolidado** (stock actual, consumo por área odontología/estética, movimientos del período).
   - Acceso al **Dashboard de Inventario** (gráficos de insumos más consumidos y alertas de reposición).

### 🚫 Qué NO DEBE poder hacer (Restricciones esperadas):
- **Sin acceso a Gestión de Roles:** En la pantalla de usuarios o panel, **no debe** aparecer la opción para crear o editar la matriz de permisos de los roles.
- **Sin acceso a Backups:** No puede descargar la base de datos completa ni alterar las llaves de cifrado del servidor.
- **Sin acceso a la Configuración del Bot:** No puede cambiar tokens de API de Telegram ni credenciales de infraestructura.

---

## 5. Rol: Gestor de Inventario 📦

Es el encargado directo de la bodega, farmacia o almacén de la clínica. Su foco principal es la exactitud del stock físico, la recepción de pedidos y el despacho con criterio de caducidad.

### 🌟 Qué DEBE poder ver y hacer:
1. **Gestión de Catálogo de Materiales (`/inventario/gestion`):**
   - Crear y editar Áreas (Odontología, Estética, General, etc.) con sus íconos respectivos.
   - Crear y organizar Categorías.
   - Registrar nuevos Materiales con su stock mínimo y unidad de medida.
2. **Entrada de Nuevos Lotes (`/inventario/entrada`):**
   - Registrar la llegada de insumos físicos.
   - Asignar número de lote (o dejar vacío para autogeneración automática).
   - Definir fecha de vencimiento (u omitirla para indumentaria, uniformes, instrumental o papelería).
   - Definir fecha sugerida de alerta de caducidad (calculada automáticamente si hay fecha de vencimiento).
   - Registrar costo unitario para trazabilidad de gastos.
3. **Salidas de Material (`/inventario/salida`):**
   - Registrar entregas de materiales indicando motivo o destino.
   - El sistema aplica automáticamente el algoritmo **FEFO** (*First Expired, First Out*), descontando primero de los lotes más próximos a vencer.
4. **Ajustes de Inventario (`/inventario/ajuste`):**
   - Corregir discrepancias entre el conteo físico y el sistema.
   - Seleccionar el lote específico a ajustar y especificar el motivo obligatorio (ej. *"Rotura de frasco"*, *"Merma por caducidad"*, *"Conteo trimestral"*).
5. **Aprobación de Solicitudes de Compra:**
   - Revisar las solicitudes creadas por el personal médico y marcarlas como Aprobadas o Rechazadas tras verificar disponibilidad.
6. **Alertas de Inventario:**
   - Ver alertas destacadas en la pantalla de inicio sobre materiales que alcanzaron o están por debajo de su stock mínimo, y lotes vencidos o próximos a vencer.

### 🚫 Qué NO DEBE poder hacer (Restricciones esperadas):
- **Sin Panel de Administración:** No puede ingresar a `/admin`, no ve el botón de administración en el menú principal ni en su perfil.
- **Sin Gestión de Usuarios:** No puede crear usuarios, cambiar contraseñas de terceros ni ver listas de cuentas.
- **Sin acceso a Backups ni Auditoría Global de Usuarios.**

---

## 6. Rol: Doctor (Personal Médico/Asistencial) 🩺

Es el perfil de los odontólogos, médicos estéticos y asistentes de consultorio. Su experiencia está optimizada para ser rápida, limpia y sin sobrecarga administrativa.

### 🌟 Qué DEBE poder ver y hacer:
1. **Consulta Rápida de Catálogo y Stock:**
   - Ver lista de materiales disponibles con búsqueda en tiempo real por nombre.
   - Filtrar por Área (Odontología / Estética) y por Categoría.
   - Acceder al detalle de cada material para verificar:
     - Stock total disponible.
     - Indicador visual de estado (Normal, Advertencia o Crítico).
     - Lista de lotes disponibles con sus fechas de vencimiento (o "Sin caducidad").
2. **Registro de Consumo / Salidas (`/inventario/salida`):**
   - Registrar el material que utilizó durante una atención o procedimiento.
   - Ingresar la cantidad utilizada y el motivo (ej. *"Atención paciente Juan Pérez - Endodoncia"*).
   - El sistema descuenta del lote óptimo sin requerir que el médico busque el lote manualmente.
3. **Solicitar Reposición de Material (`/inventario/solicitar`):**
   - **Para material existente:** Seleccionar el material agotado o por agotarse, indicar la cantidad requerida y justificación.
   - **Para nuevo material:** Proponer un material que aún no existe en catálogo indicando nombre sugerido, área, categoría y justificación de compra.
4. **Bandeja "Mis Solicitudes" (`/inventario/mis-solicitudes`):**
   - Consultar el historial de solicitudes enviadas por él mismo.
   - Ver el estado en tiempo real:
     - 🟡 **Pendiente:** En espera de revisión.
     - 🟢 **Aprobada:** Con fecha y observaciones de aprobación.
     - 🔴 **Rechazada:** Con motivo del rechazo para conocimiento del médico.
   - **Editar Solicitud:** Puede editar la cantidad o comentarios de sus solicitudes **únicamente mientras sigan en estado Pendiente**.
5. **Actividad Reciente:**
   - En su pantalla de inicio (`/home`) visualiza su tarjeta personal de *"Mi Actividad Reciente"* con los últimos consumos y solicitudes que ha efectuado.
6. **Perfil y Seguridad:**
   - Actualizar sus datos personales.
   - Cambiar su propia contraseña.
   - Vincular su cuenta con el Bot de Telegram de la clínica para recibir notificaciones sobre la resolución de sus solicitudes.

### 🚫 Qué NO DEBE poder hacer (Restricciones esperadas):
- **Sin Gestión de Catálogo:** No ve el botón de *"Gestión Catálogo"* ni puede crear/editar áreas, categorías ni materiales.
- **Sin Registro de Entradas:** No ve la opción *"Nueva Entrada"* ni puede dar de alta lotes.
- **Sin Ajustes de Stock:** No ve la opción *"Hacer Ajuste"*. Si intenta acceder por ruta directa, el sistema rechaza la acción con `403 Forbidden`.
- **Sin Aprobación de Solicitudes:** No ve la opción *"Resolver Solicitudes"*; no puede auto-aprobarse pedidos.
- **Sin acceso a Configuración ni Usuarios.**

---

## 7. Estado: Usuario Inactivo / Restringido 🚫

Si un colaborador deja de laborar en la clínica o su acceso es revocado temporalmente, el Administrador o Superadmin cambia su estado a **Inactivo**.

### 🌟 Comportamiento esperado del sistema:
1. **Invalidación de Sesión Inmediata:**
   - Gracias al mecanismo de `session_version` en backend, cualquier token JWT emitido previamente es rechazado de inmediato.
2. **Redirección a Pantalla Restringida (`/vista-restringida`):**
   - Si el usuario abre la app móvil o intenta navegar, es interceptado y enviado a la vista con el mensaje:
     > *"Acceso Restringido: Tu cuenta ha sido desactivada por un administrador. Si consideras que es un error, contacta a la administración de la clínica."*
3. **Bloqueo Total de Endpoints:**
   - Cualquier petición HTTP contra el backend retorna `403 Forbidden` o `401 Unauthorized`.
4. **Permisos en Modo Congelado:**
   - Sólo se permite la lectura de su propio historial previo para fines de auditoría personal si fuese necesario.

---

## 8. Flujos de Prueba Cruzados (Interacción entre Roles)

Para comprobar que el sistema funciona armónicamente, te recomendamos ejecutar estos 3 flujos interactuando entre roles:

### 🔄 Flujo A: Ciclo de Solicitud y Abastecimiento
1. **Inicia sesión como Doctor (`jherkisdoctor`):**
   - Ve a *"Solicitar Material"* y pide 10 unidades de un insumo (o propón uno nuevo).
   - Ve a *"Mis Solicitudes"* y confirma que aparece en estado **Pendiente**.
2. **Cierra sesión e inicia sesión como Administrador (`jherkisad`) o Gestor (`jherkisin`):**
   - Entra a *"Resolver Solicitudes"*.
   - Verás la solicitud del Doctor. Presiona **Aprobar** y añade una nota (ej. *"Aprobado para compra de urgencia"*).
3. **Vuelve a entrar como Doctor (`jherkisdoctor`):**
   - Entra a *"Mis Solicitudes"*.
   - Verifica que el estado cambió a **Aprobada** (color verde) y muestra la nota del administrador.

---

### 🔄 Flujo B: Consumo FEFO con Múltiples Lotes
1. **Inicia sesión como Gestor (`jherkisin`) o Superadmin (`admin`):**
   - Registra una **Entrada** para el material *"Guantes de Látex"*:
     - Lote A: 10 unidades, Vencimiento: Dentro de 3 meses.
   - Registra una segunda **Entrada** para el mismo material:
     - Lote B: 20 unidades, Vencimiento: Dentro de 1 mes (vence antes).
2. **Inicia sesión como Doctor (`jherkisdoctor`):**
   - Registra una **Salida** de 5 unidades del material.
3. **Verificación:**
   - Ve al detalle del material.
   - Comprueba que las 5 unidades fueron descontadas del **Lote B** (por ser el más próximo a vencer, principio FEFO).

---

### 🔄 Flujo C: Seguridad y Desactivación de Cuenta
1. **Inicia sesión como Superadmin (`admin`):**
   - Ve al Panel de Administración > *"Gestión de Usuarios"*.
   - Edita al usuario de prueba y desmarca la casilla **Activo**. Guarda los cambios.
2. **Intenta interactuar con esa cuenta en la App:**
   - Observa que la app lo expulsa o lo envía de inmediato a la pantalla de **Vista Restringida**.
3. **Vuelve a activarlo como Superadmin:**
   - El usuario recupera su acceso inmediatamente al volver a iniciar sesión.

---

## 9. Checklist Interactivo de Validación

Usa esta lista para marcar conforme vayas probando cada funcionalidad en el sistema:

### Superadmin 👑
- [ ] Iniciar sesión y ver el chip con corona dorada `Superadmin` en la cabecera.
- [ ] Entrar al Panel de Administración (`/admin`).
- [ ] Ver y listar los roles del sistema en `/admin/roles`.
- [ ] Crear un rol personalizado con 2 o 3 permisos específicos.
- [ ] Ver y editar un usuario en `/admin/usuarios`.
- [ ] Generar un respaldo de base de datos manual en `/admin/backups`.
- [ ] Consultar el registro de auditoría en `/admin/auditoria`.
- [ ] Generar un Reporte PDF de inventario y descargarlo o compartirlo.

### Administrador 🏢
- [ ] Iniciar sesión y ver el chip `Administrador`.
- [ ] Entrar a Gestión de Usuarios y crear una nueva cuenta.
- [ ] Verificar que **NO** tiene opción para editar o crear roles de sistema.
- [ ] Ir a *"Resolver Solicitudes"* y aprobar una solicitud pendiente.
- [ ] Ir a *"Resolver Solicitudes"* y rechazar una solicitud con motivo.
- [ ] Entrar al *"Dashboard"* y visualizar las gráficas de consumo.

### Gestor de Inventario 📦
- [ ] Iniciar sesión y ver el chip `GestorInventario`.
- [ ] Entrar a *"Gestión Catálogo"* y crear una nueva Área con un ícono temático.
- [ ] Crear una Categoría asignada a esa nueva Área.
- [ ] Crear un Material asignado a la categoría.
- [ ] Registrar una **Entrada de Lote** con fecha de caducidad obligatoria / sugerida.
- [ ] Registrar una **Entrada de Lote** para indumentaria sin fecha de caducidad (verificar que guarde sin error).
- [ ] Realizar un **Ajuste de Inventario** manual sobre un lote existente con motivo justificado.
- [ ] Verificar que **NO** aparece ningún botón para administrar usuarios ni servidores.

### Doctor 🩺
- [ ] Iniciar sesión y ver el chip `Doctor`.
- [ ] Ver en el inicio únicamente los accesos permitidos (*Ver Inventario*, *Registrar Salida*, *Solicitar Material*, *Mis Solicitudes*).
- [ ] Buscar y filtrar materiales por área y categoría.
- [ ] Registrar una **Salida de Material** con cantidad y motivo clínico.
- [ ] Crear una **Solicitud de Reposición** de material existente.
- [ ] Crear una **Solicitud de Nuevo Material** no catalogado.
- [ ] Ver el estado de sus pedidos en *"Mis Solicitudes"*.
- [ ] Editar una solicitud pendiente suya.
- [ ] Intentar navegar a `/admin` o `/inventario/entrada` y comprobar que el acceso es bloqueado.
- [ ] Ver su *"Actividad Reciente"* en el Home con sus propios movimientos.
- [ ] Entrar a su Perfil y vincular su cuenta de Telegram para recibir avisos.
