import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/theme/ceos_colors.dart';
import '../../core/theme/ceos_theme.dart';
import '../../models/usuario_model.dart';
import '../../providers/storage_provider.dart';

class GenerarReportePDFScreen extends ConsumerStatefulWidget {
  const GenerarReportePDFScreen({super.key});

  @override
  ConsumerState<GenerarReportePDFScreen> createState() => _GenerarReportePDFScreenState();
}

class _GenerarReportePDFScreenState extends ConsumerState<GenerarReportePDFScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Estado pestaña Generar
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  UsuarioModel? _usuarioFiltro;
  List<UsuarioModel> _usuarios = [];
  String _canalActivo = 'Telegram';
  bool _isLoading = false;
  bool _generado = false;
  int? _reporteId;
  String? _filename;
  String? _pdfBase64;
  Map<String, dynamic>? _resumen;
  String? _errorMessage;

  // Estado pestaña Historial (T-REPORTE-HIST.3)
  List<Map<String, dynamic>> _historial = [];
  bool _isLoadingHistorial = false;
  String? _historialError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _historial.isEmpty && !_isLoadingHistorial) {
        _cargarHistorial();
      }
    });
    _cargarInfoInicial();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarInfoInicial() async {
    try {
      final adminRepo = ref.read(adminRepositoryProvider);
      final config = await adminRepo.obtenerConfiguracionSistema();
      final users = await adminRepo.obtenerUsuarios();

      if (mounted) {
        setState(() {
          _canalActivo = config.canalActivo.toLowerCase().contains('whats') ? 'WhatsApp' : 'Telegram';
          _usuarios = users;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _canalActivo = 'Telegram');
      }
    }
  }

  Future<void> _cargarHistorial() async {
    if (!mounted) return;
    setState(() {
      _isLoadingHistorial = true;
      _historialError = null;
    });

    try {
      final repo = ref.read(inventarioRepositoryProvider);
      final list = await repo.obtenerHistorialReportes();
      if (mounted) {
        setState(() {
          _historial = list;
          _isLoadingHistorial = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _historialError = 'Error al cargar historial: $e';
          _isLoadingHistorial = false;
        });
      }
    }
  }

  Future<void> _generarReporte() async {
    if (_fechaInicio != null && _fechaFin != null && _fechaInicio!.isAfter(_fechaFin!)) {
      setState(() {
        _errorMessage = 'La fecha de inicio no puede ser posterior a la fecha de fin.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(inventarioRepositoryProvider);
      final fmt = DateFormat('yyyy-MM-dd');

      final res = await repo.generarReportePDF(
        fechaInicio: _fechaInicio != null ? fmt.format(_fechaInicio!) : null,
        fechaFin: _fechaFin != null ? fmt.format(_fechaFin!) : null,
        usuarioId: _usuarioFiltro?.id,
      );

      setState(() {
        _generado = true;
        _reporteId = res['reporte_id'] as int? ?? res['id'] as int?;
        _filename = res['filename'] as String? ?? 'reporte_inventario.pdf';
        _pdfBase64 = res['pdf_base64'] as String?;
        if (res['resumen'] is Map) {
          _resumen = Map<String, dynamic>.from(res['resumen'] as Map);
        }
        _isLoading = false;
      });

      // Refrescar historial en segundo plano
      _cargarHistorial();
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

  Future<void> _regenerarDesdeHistorial(Map<String, dynamic> item) async {
    final params = item['parametros_regeneracion'] as Map<String, dynamic>? ?? {};
    setState(() => _isLoadingHistorial = true);

    try {
      final repo = ref.read(inventarioRepositoryProvider);
      final res = await repo.generarReportePDF(
        fechaInicio: params['fecha_inicio'] as String?,
        fechaFin: params['fecha_fin'] as String?,
        usuarioId: params['usuario_id'] as int?,
      );

      final pdfBase64 = res['pdf_base64'] as String?;
      final fname = res['filename'] as String? ?? 'reporte_regenerado.pdf';

      if (pdfBase64 != null && pdfBase64.isNotEmpty) {
        final home = Platform.environment['HOME'] ?? '/tmp';
        final downloadsDir = Directory('$home/Downloads');
        if (!downloadsDir.existsSync()) downloadsDir.createSync(recursive: true);
        final filePath = '${downloadsDir.path}/$fname';
        await File(filePath).writeAsBytes(base64Decode(pdfBase64));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Reporte regenerado y guardado en ~/Downloads/$fname'),
              backgroundColor: CeosColors.statusSuccess,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reporte regenerado exitosamente en el servidor.'),
              backgroundColor: CeosColors.statusSuccess,
            ),
          );
        }
      }

      await _cargarHistorial();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al regenerar reporte: $e'),
            backgroundColor: CeosColors.statusDanger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingHistorial = false);
      }
    }
  }

  Future<void> _enviarPorMensajeria() async {
    if (_fechaInicio != null && _fechaFin != null && _fechaInicio!.isAfter(_fechaFin!)) {
      setState(() {
        _errorMessage = 'La fecha de inicio no puede ser posterior a la fecha de fin.';
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(inventarioRepositoryProvider);
      final fmt = DateFormat('yyyy-MM-dd');
      await repo.enviarReporteMensajeria(
        reporteId: _reporteId,
        fechaInicio: _fechaInicio != null ? fmt.format(_fechaInicio!) : null,
        fechaFin: _fechaFin != null ? fmt.format(_fechaFin!) : null,
        usuarioId: _usuarioFiltro?.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reporte enviado correctamente a tu $_canalActivo.'),
            backgroundColor: CeosColors.statusSuccess,
          ),
        );
        setState(() => _isLoading = false);
      }
      _cargarHistorial();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al enviar por mensajería: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _descargarPDF() async {
    if (_pdfBase64 == null && _filename == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay datos de PDF para descargar. Genera el reporte primero.'),
          backgroundColor: CeosColors.statusWarning,
        ),
      );
      return;
    }
    try {
      final home = Platform.environment['HOME'] ?? '/tmp';
      final downloadsDir = Directory('$home/Downloads');
      if (!downloadsDir.existsSync()) downloadsDir.createSync(recursive: true);
      final fname = _filename ?? 'reporte_inventario.pdf';
      final filePath = '${downloadsDir.path}/$fname';
      if (_pdfBase64 != null && _pdfBase64!.isNotEmpty) {
        final bytes = base64Decode(_pdfBase64!);
        await File(filePath).writeAsBytes(bytes);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reporte guardado en ~/Downloads/$fname'),
            backgroundColor: CeosColors.statusSuccess,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar archivo: $e'),
            backgroundColor: CeosColors.statusDanger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          tooltip: 'Atrás',
          onPressed: () => context.canPop() ? context.pop() : context.go('/inventario'),
        ),
        title: const Text('Reportes de Inventario'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: CeosColors.areaOdontologia,
          labelColor: CeosColors.areaOdontologia,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(
              icon: Icon(PhosphorIconsRegular.filePdf, size: 20),
              text: 'Generar PDF',
            ),
            Tab(
              icon: Icon(PhosphorIconsRegular.clockCounterClockwise, size: 20),
              text: 'Historial',
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildTabGenerar(),
            _buildTabHistorial(),
          ],
        ),
      ),
    );
  }

  Widget _buildTabGenerar() {
    final fmt = DateFormat('dd/MM/yyyy');

    return SingleChildScrollView(
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

          Text(
            'Filtros de Reporte',
            style: CeosTheme.heading(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Rango de Fechas
          Row(
            children: [
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _fechaInicio == null ? 'Fecha Inicio' : fmt.format(_fechaInicio!),
                    style: CeosTheme.body(fontSize: 13),
                  ),
                  trailing: const Icon(PhosphorIconsRegular.calendar, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _fechaInicio ?? DateTime.now().subtract(const Duration(days: 30)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _fechaInicio = picked);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _fechaFin == null ? 'Fecha Fin' : fmt.format(_fechaFin!),
                    style: CeosTheme.body(fontSize: 13),
                  ),
                  trailing: const Icon(PhosphorIconsRegular.calendar, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _fechaFin ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _fechaFin = picked);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Filtro por Usuario
          DropdownButtonFormField<UsuarioModel?>(
            decoration: const InputDecoration(
              labelText: 'Filtrar por Usuario (Opcional)',
              prefixIcon: Icon(PhosphorIconsRegular.user),
            ),
            initialValue: _usuarioFiltro,
            items: [
              const DropdownMenuItem<UsuarioModel?>(
                value: null,
                child: Text('Todos los usuarios'),
              ),
              ..._usuarios.map((u) => DropdownMenuItem<UsuarioModel?>(
                    value: u,
                    child: Text(u.nombreCompleto.isNotEmpty ? u.nombreCompleto : u.username),
                  )),
            ],
            onChanged: (val) => setState(() => _usuarioFiltro = val),
          ),
          const SizedBox(height: 24),

          // Botón Generar
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _isLoading ? null : _generarReporte,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Generar Reporte PDF'),
          ),

          // Resultados / Panel de Acciones Dual (HU-421)
          if (_generado) ...[
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(PhosphorIconsRegular.checkCircle, color: CeosColors.statusSuccess, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Reporte PDF Generado',
                          style: CeosTheme.heading(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Archivo: ${_filename ?? "reporte_inventario.pdf"}',
                      style: CeosTheme.body(fontSize: 12, color: Colors.grey[700]),
                    ),
                    if (_resumen != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Período: ${_resumen!['periodo_str'] ?? "General"}',
                              style: CeosTheme.body(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Ingresos: ${_resumen!['total_ingresos'] ?? 0}', style: CeosTheme.body(fontSize: 11)),
                                Text('Salidas: ${_resumen!['total_salidas'] ?? 0}', style: CeosTheme.body(fontSize: 11)),
                                Text('Ajustes: ${_resumen!['total_ajustes'] ?? 0}', style: CeosTheme.body(fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(PhosphorIconsRegular.downloadSimple),
                            label: const Text('Descargar'),
                            onPressed: _descargarPDF,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: CeosColors.areaOdontologia),
                            icon: const Icon(PhosphorIconsRegular.paperPlaneRight),
                            label: Text('Enviar por $_canalActivo'),
                            onPressed: _isLoading ? null : _enviarPorMensajeria,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabHistorial() {
    if (_isLoadingHistorial && _historial.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_historialError != null && _historial.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(PhosphorIconsRegular.warningCircle, size: 40, color: CeosColors.statusDanger),
              const SizedBox(height: 12),
              Text(_historialError!, textAlign: TextAlign.center, style: CeosTheme.body(color: CeosColors.statusDanger)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _cargarHistorial,
                icon: const Icon(PhosphorIconsRegular.arrowsClockwise),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_historial.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIconsRegular.clockCounterClockwise, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                'Sin reportes generados aún',
                style: CeosTheme.heading(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[700]),
              ),
              const SizedBox(height: 8),
              Text(
                'Los reportes que generes quedarán registrados aquí para regenerarlos con un solo toque.',
                textAlign: TextAlign.center,
                style: CeosTheme.body(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _tabController.animateTo(0),
                icon: const Icon(PhosphorIconsRegular.plus),
                label: const Text('Generar el primer reporte'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarHistorial,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _historial.length,
        itemBuilder: (context, index) {
          final item = _historial[index];
          final periodo = item['periodo'] as String? ?? 'Histórico general';
          final generadoPor = item['generado_por_nombre'] as String? ?? item['generado_por'] as String? ?? 'Sistema';
          final generadoEn = item['generado_en'] as String? ?? '';
          final totales = item['totales'] as Map<String, dynamic>? ?? {};
          final enviadoMensajeria = item['enviado_mensajeria'] as bool? ?? item['enviado_por_mensajeria'] as bool? ?? false;

          return Card(
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: CeosColors.areaOdontologia.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(PhosphorIconsRegular.filePdf, color: CeosColors.areaOdontologia, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              periodo,
                              style: CeosTheme.heading(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Por $generadoPor · $generadoEn',
                              style: CeosTheme.body(fontSize: 11, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      if (enviadoMensajeria)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: CeosColors.statusSuccessLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(PhosphorIconsRegular.paperPlaneTilt, size: 12, color: CeosColors.statusSuccess),
                              const SizedBox(width: 4),
                              Text(
                                'Mensajería',
                                style: CeosTheme.body(fontSize: 10, color: CeosColors.statusSuccess, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Totales snapshot
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _badgeTotal('Ingresos: ${totales["ingresos"] ?? 0}', Colors.teal),
                      _badgeTotal('Salidas: ${totales["salidas"] ?? 0}', Colors.blue),
                      _badgeTotal('Ajustes: ${totales["ajustes"] ?? 0}', Colors.orange),
                      _badgeTotal('Solicitudes: ${totales["solicitudes"] ?? 0}', Colors.purple),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      onPressed: _isLoadingHistorial ? null : () => _regenerarDesdeHistorial(item),
                      icon: const Icon(PhosphorIconsRegular.arrowsClockwise, size: 14),
                      label: const Text('Regenerar PDF', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _badgeTotal(String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: CeosTheme.body(fontSize: 10, color: color[800] ?? color, fontWeight: FontWeight.w500),
      ),
    );
  }
}
