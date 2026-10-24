import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/theme/ceos_colors.dart';
import '../../core/theme/ceos_theme.dart';
import '../../models/inventario_models.dart';
import '../../providers/inventario_providers.dart';
import '../../providers/storage_provider.dart';

class EditarSolicitudScreen extends ConsumerStatefulWidget {
  final int solicitudId;

  const EditarSolicitudScreen({
    super.key,
    required this.solicitudId,
  });

  @override
  ConsumerState<EditarSolicitudScreen> createState() => _EditarSolicitudScreenState();
}

class _EditarSolicitudScreenState extends ConsumerState<EditarSolicitudScreen> {
  final _cantidadController = TextEditingController();
  final _comentarioController = TextEditingController();
  String _motivo = 'Sin stock disponible';
  bool _isLoading = true;
  String? _errorMessage;
  SolicitudModel? _solicitud;

  final List<String> _catalogoMotivos = [
    'Sin stock disponible',
    'Reposición preventiva (baja rotación)',
    'Aumento de demanda en cirugías',
    'Material próximo a vencer',
    'Otro motivo',
  ];

  @override
  void initState() {
    super.initState();
    _cargarSolicitud();
  }

  Future<void> _cargarSolicitud() async {
    try {
      final repo = ref.read(inventarioRepositoryProvider);
      final mis = await repo.obtenerMisSolicitudes();
      final match = mis.firstWhere((s) => s.id == widget.solicitudId);
      setState(() {
        _solicitud = match;
        _cantidadController.text = match.cantidad.toString();
        _comentarioController.text = match.comentario ?? '';
        _motivo = _catalogoMotivos.contains(match.motivo) ? match.motivo : 'Otro motivo';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'No se pudo cargar la solicitud: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    _comentarioController.dispose();
    super.dispose();
  }

  Future<void> _guardarCambios() async {
    if (_isLoading) return;
    final cant = int.tryParse(_cantidadController.text.trim());
    if (cant == null || cant <= 0) {
      setState(() => _errorMessage = 'Ingresa una cantidad válida');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(inventarioRepositoryProvider);
      await repo.editarSolicitud(
        solicitudId: widget.solicitudId,
        cantidad: cant,
        motivo: _motivo,
        comentario: _comentarioController.text.trim().isNotEmpty
            ? _comentarioController.text.trim()
            : null,
      );

      ref.invalidate(misSolicitudesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solicitud actualizada con éxito.'),
            backgroundColor: CeosColors.statusSuccess,
          ),
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/inventario/solicitudes');
        }
      }
    } on AppException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Editar Solicitud')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          tooltip: 'Atrás',
          onPressed: () => context.canPop() ? context.pop() : context.go('/inventario'),
        ),
        title: const Text('Editar Solicitud'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CeosColors.statusDangerLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: CeosColors.statusDanger.withOpacity(0.3)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: CeosTheme.body(fontSize: 13, color: CeosColors.statusDanger),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (_solicitud != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: CeosColors.areaOdontologiaLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Material: ${_solicitud!.materialNombre}',
                    style: CeosTheme.heading(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              TextField(
                controller: _cantidadController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cantidad solicitada',
                  prefixIcon: Icon(PhosphorIconsRegular.hash),
                ),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _motivo,
                decoration: const InputDecoration(
                  labelText: 'Motivo',
                  prefixIcon: Icon(PhosphorIconsRegular.notePencil),
                ),
                items: _catalogoMotivos.map((m) {
                  return DropdownMenuItem(value: m, child: Text(m));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _motivo = val);
                },
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _comentarioController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Comentario opcional',
                  prefixIcon: Icon(PhosphorIconsRegular.chatCircleText),
                ),
              ),
              const SizedBox(height: 28),

              ElevatedButton(
                onPressed: _guardarCambios,
                child: const Text('Guardar Cambios'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
