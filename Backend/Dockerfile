# ============================================================
# CEOS Backend — Dockerfile (producción)
# Base: Python 3.11-slim  (estable en Koyeb)
# ============================================================

# ---- Etapa 1: dependencias ----
FROM python:3.11-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /build

# Herramientas de compilación necesarias para weasyprint / psycopg2
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        libpq-dev \
        libcairo2 \
        libpango-1.0-0 \
        libpangocairo-1.0-0 \
        libgdk-pixbuf-2.0-0 \
        libffi-dev \
        shared-mime-info \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --upgrade pip \
 && pip install --no-cache-dir -r requirements.txt

# ---- Etapa 2: imagen final ----
FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8000

WORKDIR /app

# Librerías de runtime (sin compiladores)
RUN apt-get update && apt-get install -y --no-install-recommends \
        libpq5 \
        libcairo2 \
        libpango-1.0-0 \
        libpangocairo-1.0-0 \
        libgdk-pixbuf-2.0-0 \
        shared-mime-info \
    && rm -rf /var/lib/apt/lists/*

# Copiar paquetes instalados desde builder
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Copiar código fuente
COPY . .

# Dar permisos de ejecución al entrypoint
RUN chmod +x entrypoint.sh

# Crear directorios para estáticos, media y caché de fuentes, y asignar permisos al usuario ceos
RUN addgroup --system ceos && adduser --system --ingroup ceos --home /home/ceos ceos \
    && mkdir -p /app/staticfiles /app/media /home/ceos/.cache/fontconfig \
    && chown -R ceos:ceos /app /home/ceos

ENV HOME=/home/ceos
USER ceos

EXPOSE 8000

ENTRYPOINT ["./entrypoint.sh"]

# Gunicorn dinámico (soporta $PORT de Render/Koyeb o 8000 por defecto)
CMD ["sh", "-c", "gunicorn config.wsgi:application --bind 0.0.0.0:${PORT:-8000} --workers 2 --timeout 120 --log-level info --access-logfile - --error-logfile -"]

