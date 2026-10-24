"""
simulacion_carga.py
===================
Simula carga real de la BD de CEOS con 100 usuarios clínicos, 200 lotes,
2 500 movimientos de salida, 500 solicitudes, 1 000 notificaciones y
3 500 registros de auditoría para medir el tamaño exacto en disco.

Uso (desde /home/v4/Ceos/Backend):
    python simulacion_carga.py
"""
import os
import sys
import django

# ── Configuración Django ────────────────────────────────────────────────────
TEMP_DB = os.path.abspath('tmp_simulacion.sqlite3')

if os.path.exists(TEMP_DB):
    os.remove(TEMP_DB)

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

# Redirigir la BD a la temporal ANTES de cualquier query
from django.conf import settings
from django.db import connection

settings.DATABASES['default']['NAME'] = TEMP_DB
connection.close()

from django.core.management import call_command

print("─" * 55)
print("  SIMULACIÓN DE CARGA — CEOS Clínica")
print("─" * 55)
print("\n[0] Ejecutando migraciones en base de datos temporal…")
call_command('migrate', verbosity=0)

initial_size = os.path.getsize(TEMP_DB)
print(f"    Tamaño inicial (esquema vacío): {initial_size / 1024:.1f} KB")

# ── Imports de modelos reales ───────────────────────────────────────────────
from django.utils import timezone
from datetime import timedelta
import random
import json

from apps.usuarios.models import Usuario, Rol
from apps.inventario.models import Area, CategoriaMaterial, Material
from apps.inventario.models_lotes import Lote
from apps.inventario.models_movimientos import MovimientoSalida, MovimientoSalidaLote
from apps.inventario.models_solicitudes import SolicitudMaterial
from apps.notificaciones.models import NotificacionApp
from apps.auditoria.models import RegistroAuditoria

# ── 1. Catálogo base ────────────────────────────────────────────────────────
print("\n[1] Creando catálogo base (Áreas, Categorías, Materiales, Roles)…")

rol_odontologo, _ = Rol.objects.get_or_create(
    nombre='Odontólogo', defaults={'descripcion': 'Personal médico odontólogo'})
rol_asistente, _ = Rol.objects.get_or_create(
    nombre='Asistente Dental', defaults={'descripcion': 'Asistente de clínica dental'})
rol_admin, _ = Rol.objects.get_or_create(
    nombre='Administrador', defaults={'descripcion': 'Gestor administrativo'})

area_odonto, _ = Area.objects.get_or_create(
    nombre='Odontología General', defaults={'icono': 'tooth'})
area_orto, _ = Area.objects.get_or_create(
    nombre='Ortodoncia', defaults={'icono': 'brackets'})
area_estetica, _ = Area.objects.get_or_create(
    nombre='Estética Dental', defaults={'icono': 'sparkles'})

cat_anestesia, _ = CategoriaMaterial.objects.get_or_create(
    nombre='Anestésicos', defaults={'area': area_odonto, 'icono': 'syringe'})
cat_resinas, _ = CategoriaMaterial.objects.get_or_create(
    nombre='Resinas y Adhesivos', defaults={'area': area_odonto, 'icono': 'drop'})
cat_bioseguridad, _ = CategoriaMaterial.objects.get_or_create(
    nombre='Bioseguridad', defaults={'area': area_odonto, 'icono': 'shield'})
cat_brackets, _ = CategoriaMaterial.objects.get_or_create(
    nombre='Brackets y Arcos', defaults={'area': area_orto, 'icono': 'brackets'})
cat_blanqueamiento, _ = CategoriaMaterial.objects.get_or_create(
    nombre='Blanqueamiento', defaults={'area': area_estetica, 'icono': 'star'})

# Materiales reales del catálogo
nombres_mat = [
    ('Lidocaína 2% con Epinefrina', cat_anestesia, area_odonto, 'caja'),
    ('Mepivacaína 3% sin Vasoconstrictor', cat_anestesia, area_odonto, 'caja'),
    ('Articaína 4% con Epinefrina', cat_anestesia, area_odonto, 'caja'),
    ('Resina Compuesta A2 Filtek Supreme', cat_resinas, area_odonto, 'tubo'),
    ('Resina Compuesta A3 Filtek Supreme', cat_resinas, area_odonto, 'tubo'),
    ('Resina Compuesta B1 Filtek Supreme', cat_resinas, area_odonto, 'tubo'),
    ('Adhesivo Single Bond Universal 3M', cat_resinas, area_odonto, 'frasco'),
    ('Adhesivo Optibond FL', cat_resinas, area_odonto, 'frasco'),
    ('Guantes de Nitrilo Talla M', cat_bioseguridad, area_odonto, 'caja'),
    ('Guantes de Nitrilo Talla S', cat_bioseguridad, area_odonto, 'caja'),
    ('Guantes de Nitrilo Talla L', cat_bioseguridad, area_odonto, 'caja'),
    ('Mascarillas Quirúrgicas Tricapa', cat_bioseguridad, area_odonto, 'caja'),
    ('Mascarillas N95', cat_bioseguridad, area_odonto, 'caja'),
    ('Baberos Desechables', cat_bioseguridad, area_odonto, 'paquete'),
    ('Brackets Metálicos Roth 022', cat_brackets, area_orto, 'set'),
    ('Brackets Cerámicos Roth 018', cat_brackets, area_orto, 'set'),
    ('Arco Niti Redondo 014 Superior', cat_brackets, area_orto, 'paquete'),
    ('Arco Niti Redondo 016 Inferior', cat_brackets, area_orto, 'paquete'),
    ('Ligaduras Elásticas Ortodoncia', cat_brackets, area_orto, 'bolsa'),
    ('Gel Blanqueador Opalescence 35%', cat_blanqueamiento, area_estetica, 'jeringa'),
]

materiales = []
for nom, cat, area, unidad in nombres_mat:
    mat, _ = Material.objects.get_or_create(
        nombre=nom,
        area=area,
        categoria=cat,
        defaults={
            'unidad_medida': unidad,
            'stock_minimo': 10,
        }
    )
    materiales.append(mat)

print(f"    {len(materiales)} materiales | {CategoriaMaterial.objects.count()} categorías | {Area.objects.count()} áreas")

# ── 2. 100 Usuarios ──────────────────────────────────────────────────────────
print("\n[2] Creando 100 usuarios clínicos…")
usuarios = []
for i in range(1, 101):
    u = Usuario.objects.create_user(
        username=f"dr_usuario_{i:03d}",
        correo_interno=f"usuario_{i:03d}@ceosclinica.com",
        password="Password123*",
        nombre_completo=f"Dr. Nombre{i} Apellido{i}",
        primer_login_completado=True,
    )
    if i <= 60:
        u.roles.add(rol_odontologo)
    elif i <= 90:
        u.roles.add(rol_asistente)
    else:
        u.roles.add(rol_admin)
    usuarios.append(u)

print(f"    {len(usuarios)} usuarios creados (60 odontólogos / 30 asistentes / 10 admins)")

# ── 3. 200 Lotes con stock inicial ─────────────────────────────────────────
print("\n[3] Generando 200 lotes de inventario…")
lotes = []
now = timezone.now()

for i in range(200):
    mat = random.choice(materiales)
    u_ingreso = random.choice(usuarios[:10])  # Solo admins/coordinadores ingresan lotes
    dias_venc = random.randint(60, 730)
    fecha_cad = (now + timedelta(days=dias_venc)).date()
    fecha_alerta = (now + timedelta(days=max(dias_venc - 30, 1))).date()
    cantidad_ing = random.randint(50, 200)

    lote = Lote.objects.create(
        material=mat,
        codigo_lote=f"LOT-SIM-{2026000 + i}",
        cantidad_ingresada=cantidad_ing,
        cantidad_disponible=cantidad_ing,
        costo=round(random.uniform(5.0, 120.0), 2),
        costo_registrado=True,
        fecha_caducidad=fecha_cad,
        fecha_alerta_vencimiento=fecha_alerta,
        usuario_ingreso=u_ingreso,
    )
    lotes.append(lote)

print(f"    {len(lotes)} lotes creados")
print(f"    Stock total disponible: {sum(l.cantidad_disponible for l in lotes):,} unidades")

# ── 4. 2 500 Movimientos de Salida (FEFO simulado) ─────────────────────────
print("\n[4] Simulando 2,500 movimientos de salida de inventario…")

salidas_bulk = []
detalles_bulk = []

for i in range(2500):
    u = random.choice(usuarios)
    lote = random.choice(lotes)
    mat = lote.material
    cant = random.randint(1, min(10, lote.cantidad_disponible or 1))

    # Descontar del lote (simplificado para la simulación)
    if lote.cantidad_disponible >= cant:
        lote.cantidad_disponible -= cant
    else:
        cant = max(lote.cantidad_disponible, 1)
        lote.cantidad_disponible = 0

    salida = MovimientoSalida(
        material=mat,
        cantidad_total=cant,
        motivo_destino=f"Procedimiento clínico {i} — Sillón {random.randint(1, 8)}",
        usuario=u,
    )
    salidas_bulk.append(salida)

# Guardar lotes actualizados en batch
Lote.objects.bulk_update(lotes, ['cantidad_disponible'])

# Guardar salidas
MovimientoSalida.objects.bulk_create(salidas_bulk)

# Crear detalles (1 detalle por salida)
salidas_creadas = list(MovimientoSalida.objects.order_by('-fecha_hora')[:2500])
for i, salida in enumerate(salidas_creadas):
    lote = random.choice(lotes)
    detalles_bulk.append(MovimientoSalidaLote(
        movimiento_salida=salida,
        lote=lote,
        cantidad_descontada=salida.cantidad_total,
    ))
MovimientoSalidaLote.objects.bulk_create(detalles_bulk)

print(f"    {MovimientoSalida.objects.count()} salidas | {MovimientoSalidaLote.objects.count()} detalles de lote")

# ── 5. 500 Solicitudes de Material ─────────────────────────────────────────
print("\n[5] Generando 500 solicitudes de reposición…")
solicitudes_bulk = []
estados = ['pendiente', 'aprobada', 'rechazada', 'cancelada']
pesos_estado = [0.4, 0.35, 0.15, 0.10]

for i in range(500):
    u = random.choice(usuarios)
    mat = random.choice(materiales)
    estado = random.choices(estados, weights=pesos_estado)[0]
    area = mat.area

    solicitudes_bulk.append(SolicitudMaterial(
        solicitante=u,
        material=mat,
        area=area,
        unidad_medida=mat.unidad_medida,
        cantidad_solicitada=random.randint(5, 50),
        motivo=f"Reposición urgente para sillón clínico {random.randint(1, 8)} — ciclo {i}",
        estado=estado,
        comentario_resolucion='Aprobado por coordinación' if estado == 'aprobada' else '',
    ))

SolicitudMaterial.objects.bulk_create(solicitudes_bulk)
print(f"    {SolicitudMaterial.objects.count()} solicitudes creadas")

# ── 6. 1 000 Notificaciones In-App ──────────────────────────────────────────
print("\n[6] Generando 1,000 notificaciones in-app…")
notif_bulk = []
tipos_notif = ['stock_bajo', 'solicitud_aprobada', 'solicitud_rechazada', 'vencimiento', 'general']

for i in range(1000):
    u = random.choice(usuarios)
    mat = random.choice(materiales)
    tipo = random.choice(tipos_notif)
    leida = random.random() > 0.4  # 60% leídas

    notif_bulk.append(NotificacionApp(
        usuario=u,
        titulo=f"[{tipo.upper().replace('_', ' ')}] {mat.nombre}",
        mensaje=(
            f"El material '{mat.nombre}' requiere atención. "
            f"Evento registrado en el ciclo de simulación #{i + 1}."
        ),
        leida=leida,
        tipo=tipo,
    ))

NotificacionApp.objects.bulk_create(notif_bulk)
print(f"    {NotificacionApp.objects.count()} notificaciones creadas")

# ── 7. 3 500 Registros de Auditoría Inmutables ──────────────────────────────
print("\n[7] Generando 3,500 registros de auditoría inmutables…")
auditoria_bulk = []
acciones = [
    'LOGIN_EXITOSO', 'LOGOUT',
    'SALIDA_MATERIAL', 'ENTRADA_LOTE',
    'APROBACION_SOLICITUD', 'RECHAZO_SOLICITUD',
    'CAMBIO_PASSWORD', 'EXPORTAR_REPORTE_PDF',
    'VER_INVENTARIO', 'CREAR_USUARIO',
]

for i in range(3500):
    u = random.choice(usuarios)
    accion = random.choice(acciones)
    payload = {
        'modulo': 'INVENTARIO' if 'MATERIAL' in accion or 'LOTE' in accion else 'SISTEMA',
        'descripcion': f'Operación #{i + 1} registrada en ciclo de simulación',
        'ip': f"192.168.1.{random.randint(2, 250)}",
        'dispositivo': random.choice(['CEOS Mobile Android', 'CEOS Mobile Flutter Linux']),
        'timestamp_unix': 1776528000 + i,
    }
    auditoria_bulk.append(RegistroAuditoria(
        usuario=u,
        accion=accion,
        detalles=payload,
        ip_address=payload['ip'],
    ))

RegistroAuditoria.objects.bulk_create(auditoria_bulk)
print(f"    {RegistroAuditoria.objects.count()} logs de auditoría creados")

# ── Métricas antes de bajas ─────────────────────────────────────────────────
size_full = os.path.getsize(TEMP_DB)
print(f"\n{'─' * 55}")
print(f"  📊 TAMAÑO CON CARGA COMPLETA")
print(f"     100 usuarios + 2,500 movimientos + 3,500 logs")
print(f"     {size_full / (1024 * 1024):.3f} MB  ({size_full / 1024:.1f} KB)")
print(f"{'─' * 55}")

# ── 8. Simular baja de 40 usuarios ─────────────────────────────────────────
print("\n[8] Simulando baja de 40 usuarios (10 eliminados físicamente)…")
for u in usuarios[:40]:
    u.activo = False
    u.save(update_fields=['activo'])

for u in usuarios[:10]:
    u.delete()

# VACUUM para medir tamaño real post-borrado
cursor = connection.cursor()
cursor.execute("VACUUM")
size_post_delete = os.path.getsize(TEMP_DB)

print(f"    Tamaño tras bajas + VACUUM: {size_post_delete / (1024 * 1024):.3f} MB")

# ── Conteo final ────────────────────────────────────────────────────────────
print(f"\n{'─' * 55}")
print("  CONTEO FINAL DE REGISTROS")
print(f"{'─' * 55}")
print(f"  Usuarios activos      : {Usuario.objects.filter(activo=True).count()}")
print(f"  Usuarios totales      : {Usuario.objects.count()}")
print(f"  Materiales            : {Material.objects.count()}")
print(f"  Categorías            : {CategoriaMaterial.objects.count()}")
print(f"  Lotes                 : {Lote.objects.count()}")
print(f"  Movimientos Salida    : {MovimientoSalida.objects.count()}")
print(f"  Detalles Lote Salida  : {MovimientoSalidaLote.objects.count()}")
print(f"  Solicitudes           : {SolicitudMaterial.objects.count()}")
print(f"  Notificaciones In-App : {NotificacionApp.objects.count()}")
print(f"  Registros Auditoría   : {RegistroAuditoria.objects.count()}")
print(f"{'─' * 55}")
print(f"  💾 Tamaño final en disco: {size_post_delete / (1024 * 1024):.3f} MB")
print(f"  📈 Tamaño carga completa: {size_full / (1024 * 1024):.3f} MB")
print(f"{'─' * 55}")

# Proyecciones para DB real con índices PostgreSQL
pg_overhead = 1.35  # PostgreSQL añade ~35% por TOAST, WAL, índices BTREE
print(f"\n  📐 PROYECCIÓN POSTGRESQL (factor ×{pg_overhead}):")
print(f"     Estimado: {(size_full * pg_overhead) / (1024 * 1024):.2f} MB")
print(f"     Neon Free Tier:   500 MB  → {'✅ SUFICIENTE' if (size_full * pg_overhead) < 500 * 1024 * 1024 else '⚠️  REVISAR'}")
print(f"     Supabase Free:    500 MB  → {'✅ SUFICIENTE' if (size_full * pg_overhead) < 500 * 1024 * 1024 else '⚠️  REVISAR'}")
print(f"{'─' * 55}")

# Limpieza
connection.close()
if os.path.exists(TEMP_DB):
    os.remove(TEMP_DB)
print("\n  ✅ Base de datos temporal eliminada. Simulación completada.\n")
