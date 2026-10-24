# Módulo 2 — Inventario de Materiales (Extensión)
## Historia de Usuario + Tareas Backend — Íconos de Catálogo

> Continúa numeración de historias del Módulo 2: **HU-304**.
> Continúa numeración de tareas: **T-304**.

---

## ÉPICA 4.A (extensión) — Íconos para Catálogo de Áreas y Categorías

### HU-304: Como Administrador o GestorInventario, quiero asignar un ícono visual a cada Área y Categoría de material, para que el inventario se identifique rápido sin depender de imágenes.

**Criterios de aceptación:**
- Los modelos `Area` y `CategoriaMaterial` incluyen un campo `icono` (identificador de texto, ej. `"tooth"`, `"syringe"`).
- Si no se especifica un ícono al crear/editar, se asigna un ícono genérico de fallback por defecto (ej. `"package"`).
- Existe un catálogo de íconos válidos consultable desde el backend, para que la app no tenga que mantener esa lista de forma local.
- El backend valida que el `icono` enviado exista dentro del catálogo permitido antes de guardar.
- Los registros de Área/Categoría ya existentes no quedan rotos tras el cambio (reciben el ícono de fallback automáticamente).

**Tareas técnicas:**
- [x] **T-304.1** Agregar campo `icono` (`CharField`, `max_length=50`, default `"package"`) al modelo `Area`.
- [x] **T-304.2** Agregar campo `icono` (`CharField`, `max_length=50`, default `"package"`) al modelo `CategoriaMaterial`.
- [x] **T-304.3** Generar y aplicar migración de Django (`makemigrations` + `migrate`), confirmando que los registros existentes quedan con el valor default sin intervención manual.
- [x] **T-304.4** Crear catálogo de íconos válidos (puede ser una constante en backend o un modelo simple `IconoDisponible` si se prevé que crecerá o se administrará desde el panel).
- [x] **T-304.5** Endpoint `GET /inventario/iconos-disponibles` que devuelve la lista de identificadores permitidos.
- [x] **T-304.6** Actualizar los serializers de `Area` y `CategoriaMaterial` (lectura y escritura) para incluir el campo `icono`.
- [x] **T-304.7** Agregar validación en los endpoints `POST`/`PATCH` de `/inventario/areas` y `/inventario/categorias`: rechazar la solicitud si el `icono` enviado no está dentro del catálogo válido (T-304.4).
- [x] **T-304.8** Actualizar la documentación (OpenAPI/Swagger) de ambos endpoints reflejando el nuevo campo.

### 🧪 T-304.T — Test de la Épica 2.A (extensión)
- [x] Suite de tests: creación de Área/Categoría sin especificar ícono (debe asignar el fallback por defecto), creación con un ícono válido del catálogo, rechazo al enviar un ícono fuera del catálogo permitido, migración aplicada correctamente sobre registros preexistentes (verificar que no quedan con `icono` nulo), respuesta correcta del endpoint `GET /inventario/iconos-disponibles`.

---