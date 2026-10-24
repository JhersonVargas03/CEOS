# 🚀 Plan de Preparación para Producción y Despliegue — CEOS Clínico

**Proyecto:** CEOS — Sistema Integral de Gestión Odontológica, Estética e Inventario  
**Fecha de emisión:** 17 de Octubre de 2026  
**Estado del Software:** Release Candidate 1 (RC1) — Lógica de negocio y blindaje funcional completados al 100%.

---

## 📊 Diagnóstico y Estado Actual del Código

| Componente | Métrica / Evidencia | Estado |
| :--- | :--- | :---: |
| **Backend (Django REST Framework)** | **89 de 89 tests aprobados** (`manage.py test`, 100% OK). Autenticación JWT, invalidación de sesiones remotas, permisos granulares, FEFO, lotes, respaldos automáticos (Celery), auditoría inmutable e **historial/regeneración de reportes PDF**. | ✅ Listo |
| **Frontend Móvil (Flutter)** | **18 de 18 pruebas aprobadas**. **0 errores** de análisis estático (`dart analyze lib/`). Pestaña de historial de reportes con regeneración instantánea y entrega dual (descarga/mensajería). | ✅ Listo |
| **Blindaje de Entradas y Flujos** | Protección activa contra doble envío ("rage click"), cantidades negativas, fechas invertidas, validación en vivo de contraseñas seguras y fugas de memoria en temporizadores. | ✅ Listo |

---

## 📋 Hoja de Ruta para Despliegue y Pase a Producción

A continuación se detallan las 5 fases indispensables para realizar la transición segura del entorno de desarrollo al entorno operativo de la clínica.

---

### Fase 1: Control de Versiones y Respaldo de Código Base (Git)

Actualmente el directorio raíz `/home/v4/Ceos` no se encuentra versionado con Git. Es imperativo crear el repositorio antes de tocar configuraciones de producción.

1. **Configuración de `.gitignore` Profesional:**
   Asegurar que los siguientes archivos **NUNCA** se suban al repositorio:
   * Base de datos local: `*.sqlite3`
   * Entornos virtuales: `Backend/.venv/`, `.env`
   * Credenciales y tokens: Archivos con secretos de producción
   * Artefactos de Flutter: `movil/build/`, `movil/.dart_tool/`, `movil/.flutter-plugins*`
2. **Inicialización y Primer Commit:**
   ```bash
   cd /home/v4/Ceos
   git init
   git add .
   git commit -m "feat: release candidate 1 (RC1) - Sprint 4 Superadmin y blindaje completo"
   git tag -a v1.0.0-rc1 -m "Versión candidata a producción 1.0.0-rc1"
   ```

---

### Fase 2: Configuración del Backend para Producción

En el archivo `Backend/.env` (o en variables del sistema del servidor):

1. **Seguridad Básica de Django:**
   * `DEBUG=False` *(Vital: nunca encender DEBUG en producción, expone trazas de código y contraseñas)*.
   * `SECRET_KEY=clave_aleatoria_criptograficamente_segura_de_64_caracteres`
   * `ALLOWED_HOSTS=192.168.1.100,ceos.miclinica.local,api.ceos.com` *(IP local o dominio de la clínica)*.
2. **CORS y Seguridad HTTP:**
   * Configurar `CORS_ALLOWED_ORIGINS` restringido únicamente al host de la aplicación.
   * Activar cabeceras de seguridad: `SECURE_BROWSER_XSS_FILTER = True`, `SECURE_CONTENT_TYPE_NOSNIFF = True`.
3. **Servicios de Mensajería:**
   * Configurar `TELEGRAM_BOT_TOKEN` y webhook HTTPS o sondeo.
   * Configurar credenciales de Twilio WhatsApp si se activa dicho canal.

---

### Fase 3: Arquitectura del Servidor de Producción (Linux / VPS o Servidor Local)

Para garantizar alta disponibilidad y que las alertas automáticas o respaldos no se detengan al cerrar la terminal:

```
                  ┌───────────────────────────────┐
                  │    Nginx (Proxy Reverso HTTPS) │
                  └───────────────┬───────────────┘
                                  │ :8000
                  ┌───────────────▼───────────────┐
                  │      Gunicorn (WSGI Server)   │
                  │   Django API REST (Ceos App)  │
                  └───────────────┬───────────────┘
                                  │
         ┌────────────────────────┼────────────────────────┐
         │                        │                        │
┌────────▼────────┐      ┌────────▼────────┐      ┌────────▼────────┐
│ PostgreSQL / DB │      │  Redis (Broker) │      │ Celery Workers  │
│  (Persistencia) │      │ (Colas Celery)  │      │ & Celery Beat   │
└─────────────────┘      └─────────────────┘      └─────────────────┘
```

1. **Nginx:** Expone el puerto 443 (HTTPS) con certificado SSL (Let's Encrypt o autofirmado institucional de la clínica).
2. **Systemd Services:** Crear 3 servicios gestionados por el sistema operativo:
   * `ceos-api.service`: Ejecuta Gunicorn (`gunicorn config.wsgi:application --workers 3 --bind 127.0.0.1:8000`).
   * `ceos-celery-worker.service`: Ejecuta el procesador de tareas en segundo plano (`celery -A config worker -l info`).
   * `ceos-celery-beat.service`: Ejecuta el programador de tareas periódicas (`celery -A config beat -l info`).

---

### Fase 4: Generación y Empaquetado de la Aplicación Móvil (Release)

1. **Generación del APK para Android:**
   ```bash
   cd /home/v4/Ceos/movil
   flutter build apk --release --split-per-abi
   ```
   * *Resultado:* Genera APKs optimizados y livianos en `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` sin dependencias de depuración.
2. **Generación del ejecutable Linux (si se usa en PCs de recepción):**
   ```bash
   flutter build linux --release
   ```
   * *Resultado:* Binario compilado nativo en `build/linux/x64/release/bundle/`.

---

### Fase 5: Pruebas de Aceptación con Usuarios (UAT / Piloto Clínico)

Antes de la inauguración oficial con pacientes reales, ejecutar un piloto de 1 hora con personal de la clínica:

1. **Escenario Clínico Odontológico:**
   * Un odontólogo ingresa con su usuario y registra una salida de material usando FEFO.
   * El sistema debe sugerir automáticamente el lote más próximo a caducar.
2. **Escenario de Reposición y Stock Crítico:**
   * El personal solicita un material con stock bajo.
   * El Gestor de Inventario o Superadmin recibe la notificación, aprueba la solicitud y descarga el comprobante en PDF.
3. **Escenario de Seguridad y Auditoría:**
   * El Superadmin consulta la bitácora de auditoría para verificar que ambas acciones quedaron registradas con usuario, fecha, hora e IP.
   * Se ejecuta una copia de seguridad manual y se descarga el archivo comprimido `.tar.gz` o `.sql`.

---

### Fase 6: Gestión Eficiente de Reportes PDF e Inmutabilidad (Épica 2.G+)

Para optimizar el espacio de almacenamiento y garantizar la persistencia de consultas pasadas sin saturar servidores ni bases de datos gratuitas (Supabase / Neon / Koyeb):

1. **Estrategia "Cero Almacenamiento de Binarios en Servidor":**
   * Los archivos PDF pesados no se almacenan en el disco del servidor ni como `BLOB` en la base de datos.
   * Se almacena únicamente un registro liviano (`ReporteGenerado`, ~200 bytes) con: autor, periodo, filtros y totales en snapshot.
   * Dado que los movimientos de inventario (`Lote`, `MovimientoSalida`, `AjusteInventario`) son **inmutables**, la regeneración de un PDF en cualquier fecha futura reproduce un documento idéntico al emitido originalmente.
2. **Entrega y Regeneración Instantánea:**
   * El usuario descarga el PDF directo a su dispositivo (`~/Downloads` en escritorio / almacenamiento local en móvil) o lo recibe en su canal activo (Telegram/WhatsApp).
   * La pestaña de historial en la app móvil permite consultar los últimos 50 reportes y regenerar cualquiera con un solo toque.

#### Registro de Tareas de Implementación:

| Código | Tarea / Entregable | Alcance | Estado |
| :--- | :--- | :--- | :---: |
| **T-REPORTE-HIST.1** | Modelo `ReporteGenerado` + Migraciones Django (`0005`, `0006`) | `Backend/apps/inventario/models_reportes.py`. FKs a usuario, área, categoría; fechas nullables, snapshot de totales y property `parametros_regeneracion`. | ✅ Completado |
| **T-REPORTE-HIST.2** | Endpoint `GET /api/inventario/reportes/historial` | `Backend/apps/inventario/views_reportes.py`. Retorna últimos 50 reportes con control de rol (Admins ven todo, usuarios solo los suyos) y payload de regeneración. | ✅ Completado |
| **T-REPORTE-HIST.3** | Vista Flutter con TabBar (Generar / Historial) | `movil/lib/screens/inventario/generar_reporte_pdf_screen.dart`. Listado con badges de totales, estado de mensajería y botón "Regenerar PDF". | ✅ Completado |
| **T-REPORTE-HIST.4** | Suite de Tests Automatizados de Historial | `Backend/apps/inventario/tests/test_reportes.py`. Pruebas para registro automático al generar PDF, endpoint GET y aislamiento por permisos. | ✅ Completado |

---

## 📌 Conclusión
El sistema cuenta con una base de ingeniería probada y estable. Con estas recomendaciones operativas cubiertas, CEOS está preparado para operar con alta disponibilidad en la clínica.
