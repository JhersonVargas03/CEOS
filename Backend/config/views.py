from django.http import JsonResponse
from django.db import connection
from django.utils import timezone
import os

def health_check(request):
    """
    Endpoint liviano de monitoreo (Koyeb Health Check & UptimeRobot Keep-Alive).
    No requiere autenticación. Permite a los monitores externos verificar
    la disponibilidad del servicio y mantener el contenedor activo 24/7.
    """
    db_status = "ok"
    status_code = 200
    db_error = None

    try:
        connection.ensure_connection()
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1;")
            cursor.fetchone()
    except Exception as e:
        db_status = "error"
        db_error = str(e)
        status_code = 503

    return JsonResponse(
        {
            "status": "healthy" if db_status == "ok" else "degraded",
            "database": db_status,
            "version": os.environ.get("APP_VERSION", "1.0.0-rc1"),
            "timestamp": timezone.now().isoformat(),
            **({"error": db_error} if db_error else {}),
        },
        status=status_code,
    )


def app_version_check(request):
    """
    Endpoint para verificación de actualizaciones in-app (OTA).
    Permite a los dispositivos móviles consultar la versión vigente del APK,
    las novedades de la versión y la URL de descarga directa desde GitHub Releases.
    """
    version_actual = os.environ.get("APP_CURRENT_VERSION", "1.0.0")
    version_minima = os.environ.get("APP_MIN_VERSION", "1.0.0")
    url_descarga = os.environ.get(
        "APP_DOWNLOAD_URL",
        "https://github.com/JhersonVargas03/CEOS/releases/latest/download/CEOS.apk"
    )
    notas = os.environ.get(
        "APP_RELEASE_NOTES",
        "Mejoras de rendimiento, estabilidad general y actualización de funciones."
    )
    obligatoria = os.environ.get("APP_UPDATE_MANDATORY", "false").lower() in ("true", "1", "yes")

    return JsonResponse({
        "version_actual": version_actual,
        "version_minima": version_minima,
        "url_descarga": url_descarga,
        "notas": notas,
        "obligatoria": obligatoria,
        "timestamp": timezone.now().isoformat(),
    })

