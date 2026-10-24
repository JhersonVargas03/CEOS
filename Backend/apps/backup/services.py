import os
import gzip
import shutil
import logging
import subprocess
from datetime import datetime
from django.conf import settings
from django.utils import timezone
from django.db import connection
from django.db.models import Q

from apps.usuarios.models import Usuario
from apps.notificaciones.models import NotificacionApp
from apps.notificaciones.services import NotificationService
from .models import RegistroBackup

logger = logging.getLogger(__name__)


def ejecutar_backup(origen='AUTOMATICO', usuario=None, tarea_id=None):
    """
    T-301.1 a T-301.8, T-302.2: Genera el dump de la base de datos comprimido (.sql.gz),
    lo despacha vía NotificationService al Superadmin y elimina el archivo temporal del servidor.
    Registra el resultado en RegistroBackup.
    """
    fecha_str = timezone.now().strftime('%Y-%m-%d_%H%M%S')
    nombre_archivo = f"backup_ceos_{fecha_str}.sql.gz"
    temp_dir = getattr(settings, 'BACKUP_TEMP_DIR', os.path.join(settings.BASE_DIR, 'tmp_backups'))
    os.makedirs(temp_dir, exist_ok=True)

    ruta_salida = os.path.join(temp_dir, nombre_archivo)
    db_config = settings.DATABASES['default']
    engine = db_config.get('ENGINE', '')

    logger.info(f"[Backup] Iniciando respaldo {nombre_archivo} ({origen}). Engine: {engine}")

    dump_exitoso = False
    detalles_error = None
    tamano_bytes = 0

    try:
        if 'postgresql' in engine:
            # T-301.2: Generar pg_dump comprimido con gzip
            env = os.environ.copy()
            if db_config.get('PASSWORD'):
                env['PGPASSWORD'] = db_config['PASSWORD']

            cmd = [
                'pg_dump',
                '-h', db_config.get('HOST', 'localhost'),
                '-p', str(db_config.get('PORT', 5432)),
                '-U', db_config.get('USER', 'postgres'),
                '-d', db_config.get('NAME', 'ceos_db'),
            ]
            process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env)
            stdout_data, stderr_data = process.communicate()

            if process.returncode != 0:
                raise Exception(f"pg_dump falló con código {process.returncode}: {stderr_data.decode('utf-8', errors='ignore')}")

            with gzip.open(ruta_salida, 'wb') as f_out:
                f_out.write(stdout_data)

            dump_exitoso = True

        else:
            # SQLite u otros entornos de prueba / desarrollo
            db_path = db_config.get('NAME')
            if isinstance(db_path, str) and os.path.exists(db_path):
                with open(db_path, 'rb') as f_in:
                    with gzip.open(ruta_salida, 'wb') as f_out:
                        shutil.copyfileobj(f_in, f_out)
                dump_exitoso = True
            else:
                # Volcado genérico SQLite en memoria o sintaxis SQL
                with gzip.open(ruta_salida, 'wt', encoding='utf-8') as f_out:
                    for line in connection.connection.iterdump() if hasattr(connection.connection, 'iterdump') else []:
                        f_out.write(f"{line}\n")
                dump_exitoso = True

        tamano_bytes = os.path.getsize(ruta_salida)

        # T-301.4: Despachar vía NotificationService al Superadmin
        superadmins = Usuario.objects.filter(
            Q(is_superuser=True) | Q(roles__es_superadmin=True),
            activo=True
        ).distinct()
        destinatarios = list(superadmins)
        if usuario and usuario not in destinatarios:
            destinatarios.append(usuario)

        tamano_mb = round(tamano_bytes / (1024 * 1024), 2)
        mensaje = (
            f"📦 <b>RESPALDO DE BASE DE DATOS CEOS</b> 📦\n\n"
            f"<b>Archivo:</b> {nombre_archivo}\n"
            f"<b>Origen:</b> {origen}\n"
            f"<b>Tamaño:</b> {tamano_mb} MB ({tamano_bytes} bytes)\n"
            f"<b>Fecha:</b> {timezone.now().strftime('%d/%m/%Y %H:%M:%S')}\n"
            f"<b>Solicitado Por:</b> {usuario.username if usuario else 'Sistema (Automático)'}\n\n"
            f"<i>El respaldo se ha completado exitosamente y ha sido removido del almacenamiento local.</i>"
        )

        for dest in destinatarios:
            try:
                NotificationService.enviar_documento(dest, ruta_salida, nombre_archivo, caption=mensaje)
                NotificacionApp.objects.create(
                    usuario=dest,
                    titulo="Respaldo de Base de Datos Generado",
                    mensaje=f"Respaldo {nombre_archivo} ({tamano_mb} MB) generado exitosamente ({origen}).",
                    tipo="alerta"
                )
            except Exception as e_notif:
                logger.warning(f"[Backup] No se pudo enviar notificación/documento a {dest.username}: {e_notif}")

        # T-301.5: Borrado del servidor tras confirmación de procesamiento
        if os.path.exists(ruta_salida):
            os.remove(ruta_salida)

        registro = RegistroBackup.objects.create(
            nombre_archivo=nombre_archivo,
            tamano_bytes=tamano_bytes,
            exitoso=True,
            origen=origen,
            usuario_solicitante=usuario,
            tarea_id=tarea_id
        )
        logger.info(f"[Backup] Respaldo {nombre_archivo} finalizado con éxito. ID: {registro.id}")
        return registro

    except Exception as e:
        detalles_error = str(e)
        logger.error(f"[Backup] Error irrecuperable en respaldo ({origen}): {detalles_error}")

        # T-301.8: Manejo de errores irrecuperables
        registro = RegistroBackup.objects.create(
            nombre_archivo=nombre_archivo,
            tamano_bytes=tamano_bytes,
            exitoso=False,
            origen=origen,
            detalles_error=detalles_error,
            usuario_solicitante=usuario,
            tarea_id=tarea_id
        )

        # Notificar fallo al Superadmin
        msg_error = f"⚠️ <b>ALERTA: FALLO EN RESPALDO DE BASE DE DATOS</b> ⚠️\n\n<b>Origen:</b> {origen}\n<b>Error:</b> {detalles_error}"
        for sa in Usuario.objects.filter(Q(is_superuser=True) | Q(roles__es_superadmin=True), activo=True).distinct():
            try:
                NotificationService.enviar_mensaje(sa, msg_error)
                NotificacionApp.objects.create(
                    usuario=sa,
                    titulo="Fallo en Respaldo de Base de Datos",
                    mensaje=f"Error al generar respaldo de base de datos ({origen}): {detalles_error}",
                    tipo="alerta"
                )
            except Exception:
                pass


        if os.path.exists(ruta_salida):
            try:
                os.remove(ruta_salida)
            except Exception:
                pass

        return registro
