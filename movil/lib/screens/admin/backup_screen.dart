import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/theme/ceos_colors.dart';
import '../../core/theme/ceos_theme.dart';
import '../../models/admin_models.dart';
import '../../providers/permisos_provider.dart';
import '../../providers/storage_provider.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  List<BackupHistorialModel> _historial = [];
  bool _isLoading = true;
  bool _generando = false;
  String? _errorMessage;
  String? _tareaEnProcesoId;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _cargarHistorial() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(adminRepositoryProvider);
      final list = await repo.obtenerHistorialBackups();
      setState(() {
        _historial = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _generarBackup() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Generar Backup Manual?'),
        content: const Text(
          'Se creará una copia de seguridad completa de la base de datos PostgreSQL y se enviará por Telegram a tu cuenta de Superadmin.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Generar Ahora'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() {
      _generando = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(adminRepositoryProvider);
      final res = await repo.generarBackupManual();
      final tareaId = res['tarea_id'] as String? ?? res['id']?.toString();

      if (tareaId != null) {
        _tareaEnProcesoId = tareaId;
        _iniciarPollingEstado(tareaId);
      } else {
        setState(() => _generando = false);
        _cargarHistorial();
      }
    } on AppException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _generando = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _generando = false;
      });
    }
  }

  // Polling de estado de tarea Celery (HU-427)
  void _iniciarPollingEstado(String tareaId) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final repo = ref.read(adminRepositoryProvider);
        final estadoData = await repo.obtenerEstadoBackup(tareaId);
        if (!mounted) {
          timer.cancel();
          return;
        }
        final estado = (estadoData['estado'] as String? ?? '').toLowerCase();

        if (estado == 'exitoso' || estado == 'success') {
          timer.cancel();
          setState(() {
            _generando = false;
            _tareaEnProcesoId = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Backup generado y enviado exitosamente.'),
              backgroundColor: CeosColors.statusSuccess,
            ),
          );
          _cargarHistorial();
        } else if (estado == 'fallido' || estado == 'failure') {
          timer.cancel();
          setState(() {
            _generando = false;
            _errorMessage = 'Falló la generación del backup: ${estadoData["error"]}';
            _tareaEnProcesoId = null;
          });
          _cargarHistorial();
        }
      } catch (_) {
        // Stop after 30s
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final esSuperadmin = ref.watch(esSuperadminProvider);

    // Guard exclusivo para Superadmin (HU-427)
    if (!esSuperadmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Respaldo de Base de Datos')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(PhosphorIconsFill.shieldWarning, size: 48, color: CeosColors.statusDanger),
                const SizedBox(height: 16),
                Text('Acceso Exclusivo Superadmin', style: CeosTheme.heading(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('Solo la cuenta Superadmin puede generar o consultar backups.', style: CeosTheme.body(color: CeosColors.lightTextSecondary)),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          tooltip: 'Atrás',
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: const Text('Respaldo de Base de Datos'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _cargarHistorial,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Card de Generación Manual (HU-427)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      const Icon(PhosphorIconsRegular.database, size: 36, color: CeosColors.areaOdontologia),
                      const SizedBox(height: 10),
                      Text(
                        'Respaldo Manual Bajo Demanda',
                        style: CeosTheme.heading(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Recomendado antes de cambios críticos o migraciones. Se genera y envía automáticamente a Telegram.',
                        style: CeosTheme.body(fontSize: 12, color: CeosColors.lightTextSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: _generando
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(PhosphorIconsRegular.arrowCounterClockwise),
                        label: Text(_generando ? 'Generando Backup...' : 'Generar Backup Ahora'),
                        onPressed: _generando ? null : _generarBackup,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'Historial de Respaldos',
                  style: CeosTheme.heading(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_errorMessage != null)
                  Center(child: Text('Error: $_errorMessage'))
                else if (_historial.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No hay registros de backups anteriores.',
                        style: CeosTheme.body(color: CeosColors.lightTextMuted),
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _historial.length,
                    itemBuilder: (context, index) {
                      final b = _historial[index];
                      final isSuccess = b.esExitoso;
                      final color = isSuccess ? CeosColors.statusSuccess : CeosColors.statusDanger;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isSuccess ? PhosphorIconsFill.checkCircle : PhosphorIconsFill.warningCircle,
                              color: color,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            '${b.origen.toUpperCase()} • ${b.tamanoLegible}',
                            style: CeosTheme.heading(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Fecha: ${b.creadoEn}',
                            style: CeosTheme.body(fontSize: 12, color: CeosColors.lightTextSecondary),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              b.estado.toUpperCase(),
                              style: CeosTheme.dataMono(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
