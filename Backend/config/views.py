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
