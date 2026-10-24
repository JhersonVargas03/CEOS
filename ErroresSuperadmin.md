>Al crear una nueva categoria desde la vista de nuevo material me sale errores de tamano de boton: 
```
══╡ EXCEPTION CAUGHT BY
RENDERING LIBRARY
╞═════════════════════════
══════════════════════════
══════
The following assertion
was thrown during layout:
A RenderFlex overflowed by
214 pixels on the bottom.
The relevant error-causing
widget was:
  Column
  Column:file:///home/v4/C
  eos/movil/lib/widgets/se
  lector_icono_grid.dart:4
  5:12

To inspect this widget in
Flutter DevTools, visit:
http://127.0.0.1:43557/fwU
ksiIa1jw=/devtools//#/insp
ector?uri=http%3A%2F%2F127
.0.0.1%3A43557%2FfwUksiIa1
jw%3D%2F&inspectorRef=insp
ector-0

The overflowing RenderFlex
has an orientation of
Axis.vertical.
The edge of the RenderFlex
that is overflowing has
been marked in the
rendering with a yellow
and
black striped pattern.
This is usually caused by
the contents being too big
for the RenderFlex.
Consider applying a flex
factor (e.g. using an
Expanded widget) to force
the children of the
RenderFlex to fit within
the available space
instead of being sized to
their natural size.
This is considered an
error condition because it
indicates that there is
content that cannot be
seen. If the content is
legitimately bigger than
the available space,
consider clipping it with
a
ClipRect widget before
putting it in the flex, or
using a scrollable
container rather than a
Flex,
like a ListView.
The specific RenderFlex in
question is:
RenderFlex#08ae9
relayoutBoundary=up30
OVERFLOWING:
  needs compositing
  creator: Column ←
  SelectorIconoGrid ←
  Padding ← DecoratedBox ←
  ConstrainedBox ←
  Container ← Column ←
    _FormScope ←
    WillPopScope ←
    Semantics ←
    Form-[LabeledGlobalKey
    <FormState>#fae58] ←
    _SingleChildViewport ←
    ⋯
  parentData:
  offset=Offset(1.0, 1.0)
  (can use size)
  constraints:
  BoxConstraints(0.0<=w<=8
  09.0, h=178.0)
  size: Size(809.0, 178.0)
  direction: vertical
  mainAxisAlignment: start
  mainAxisSize: min
  crossAxisAlignment:
  start
  textDirection: ltr
  verticalDirection: down
  spacing: 0.0
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤
══════════════════════════
══════════════════════════
══════════════════════════
══════════════════════

Another exception was thrown: A RenderFlex overflowed by 214 pixels on the bottom.

Another exception was thrown: A RenderFlex overflowed by 214 pixels on the bottom.
```

### ✅ Solución Aplicada
- **Causa raíz**: [SelectorIconoGrid](file:///home/v4/Ceos/movil/lib/widgets/selector_icono_grid.dart) mantenía una altura fija con `SizedBox(height: 320)`. Al instanciarse dentro del `Container(height: 180)` del diálogo de nueva categoría en [crear_editar_material_screen.dart](file:///home/v4/Ceos/movil/lib/screens/inventario/crear_editar_material_screen.dart), el contenido total del `Column` medía ~392px contra un espacio disponible de 178px, produciendo el desbordamiento exacto de **214 píxeles**.
- **Cambios realizados**:
  1. **[selector_icono_grid.dart](file:///home/v4/Ceos/movil/lib/widgets/selector_icono_grid.dart)**: Se refactorizó con `LayoutBuilder` para detectar automáticamente si el contenedor padre impone una altura fija/acotada (`isTight` / `hasBoundedHeight`). Cuando es fija, utiliza `Expanded` para que la cuadrícula ocupe fluidamente el espacio restante sin generar ningún desbordamiento.
  2. **[crear_editar_material_screen.dart](file:///home/v4/Ceos/movil/lib/screens/inventario/crear_editar_material_screen.dart)**: Se mejoró el diálogo de creación rápida de categoría, añadiendo un badge con vista previa en vivo del ícono seleccionado y un contenedor con `ClipRRect` para los bordes redondeados.
  3. **[widget_test.dart](file:///home/v4/Ceos/movil/test/widget_test.dart)**: Se añadió prueba de regresión automatizada que valida que el selector renderiza sin excepciones en contenedores acotados de 180px.