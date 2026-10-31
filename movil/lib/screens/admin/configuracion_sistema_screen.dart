import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/ceos_colors.dart';
import '../../core/theme/ceos_theme.dart';
import '../../models/admin_models.dart';
import '../../providers/permisos_provider.dart';
import '../../providers/storage_provider.dart';
import '../../core/services/app_update_service.dart';

class ConfiguracionSistemaScreen extends ConsumerStatefulWidget {
  const ConfiguracionSistemaScreen({super.key});

  @override
  ConsumerState<ConfiguracionSistemaScreen> createState() => _ConfiguracionSistemaScreenState();
}

class _ConfiguracionSistemaScreenState extends ConsumerState<ConfiguracionSistemaScreen> {
  ConfiguracionSistemaModel? _config;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
  }

  Future<void> _cargarConfiguracion() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(adminRepositoryProvider);
      final config = await repo.obtenerConfiguracionSistema();
      setState(() {
        _config = config;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _cambiarCanal(String canal) async {
    try {
      final repo = ref.read(adminRepositoryProvider);
      await repo.actualizarCanalMensajeria(canal);
      _cargarConfiguracion();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Canal de mensajería cambiado a $canal.'),
            backgroundColor: CeosColors.statusSuccess,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _toggleAlertas(bool activas) async {
    try {
      final repo = ref.read(adminRepositoryProvider);
      await repo.actualizarAlertasInventario(activas);
      _cargarConfiguracion();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(activas ? 'Envío de alertas activado.' : 'Envío de alertas pausado.'),
            backgroundColor: CeosColors.statusSuccess,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final esSuperadmin = ref.watch(esSuperadminProvider);

    // Guard de acceso exclusivo para Superadmin (HU-426)
    if (!esSuperadmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Configuración del Sistema')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(PhosphorIconsFill.shieldWarning, size: 48, color: CeosColors.statusDanger),
                const SizedBox(height: 16),
                Text(
                  'Acceso Exclusivo de Superadmin',
                  style: CeosTheme.heading(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Esta pantalla sólo puede ser consultada y configurada por la cuenta Superadmin.',
                  style: CeosTheme.body(color: CeosColors.lightTextSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Configuración del Sistema')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null || _config == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowLeft),
            tooltip: 'Atrás',
            onPressed: () => context.canPop() ? context.pop() : context.go('/admin'),
          ),
          title: const Text('Configuración del Sistema'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(PhosphorIconsRegular.warningCircle, size: 48, color: CeosColors.statusDanger),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Error al cargar configuración del sistema',
                  textAlign: TextAlign.center,
                  style: CeosTheme.body(color: CeosColors.statusDanger),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _cargarConfiguracion,
                  icon: const Icon(PhosphorIconsRegular.arrowsClockwise, size: 18),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final config = _config!;
    final esTelegram = config.canalActivo.toLowerCase().contains('tele');
    final twilioConfigurado = config.twilioConfigurado;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          tooltip: 'Atrás',
          onPressed: () => context.canPop() ? context.pop() : context.go('/admin'),
        ),
        title: const Text('Configuración del Sistema'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Canal de Notificaciones y Mensajería',
                style: CeosTheme.heading(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Define por qué canal el sistema envía reportes, códigos OTP y backups automáticos.',
                style: CeosTheme.body(fontSize: 12, color: CeosColors.lightTextSecondary),
              ),
              const SizedBox(height: 14),

              // Selector de Canal: Telegram vs WhatsApp (HU-426)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        value: 'telegram',
                        groupValue: config.canalActivo.toLowerCase(),
                        activeColor: CeosColors.areaOdontologia,
                        secondary: const Icon(PhosphorIconsFill.telegramLogo, color: CeosColors.areaOdontologia),
                        title: Text('Telegram Bot (Activo)', style: CeosTheme.heading(fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text('Envío directo e ilimitado vía Bot API.', style: CeosTheme.body(fontSize: 12)),
                        onChanged: (val) {
                          if (val != null) _cambiarCanal(val);
                        },
                      ),
                      const Divider(height: 1),
                      RadioListTile<String>(
                        value: 'whatsapp',
                        groupValue: config.canalActivo.toLowerCase(),
                        secondary: Icon(
                          PhosphorIconsFill.whatsappLogo,
                          color: twilioConfigurado ? CeosColors.statusSuccess : CeosColors.lightTextMuted,
                        ),
                        title: Text('WhatsApp vía Twilio', style: CeosTheme.heading(fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          twilioConfigurado
                              ? 'Configurado y listo para enviar.'
                              : 'Deshabilitado: Requiere credenciales de Twilio en el backend.',
                          style: CeosTheme.body(
                            fontSize: 12,
                            color: twilioConfigurado ? CeosColors.lightTextSecondary : CeosColors.statusDanger,
                          ),
                        ),
                        onChanged: twilioConfigurado
                            ? (val) {
                                if (val != null) _cambiarCanal(val);
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              Text(
                'Alertas Automáticas de Inventario',
                style: CeosTheme.heading(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Envío programado de alertas de stock crítico y vencimiento próximo.',
                style: CeosTheme.body(fontSize: 12, color: CeosColors.lightTextSecondary),
              ),
              const SizedBox(height: 14),

              // Switch Alertas con texto explicativo (HU-426)
              Card(
                child: SwitchListTile(
                  value: config.alertasInventarioActivas,
                  activeColor: CeosColors.areaOdontologia,
                  title: Text(
                    'Envío Diario de Alertas',
                    style: CeosTheme.heading(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Nota: El cálculo interno de alertas en el dashboard seguirá funcionando incluso si se apaga el envío diario.',
                    style: CeosTheme.body(fontSize: 12, color: CeosColors.lightTextMuted),
                  ),
                  onChanged: _toggleAlertas,
                ),
              ),

              const SizedBox(height: 28),

              Text(
                'Actualizaciones de la Aplicación',
                style: CeosTheme.heading(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Comprueba si existe una versión más reciente de CEOS disponible para instalar.',
                style: CeosTheme.body(fontSize: 12, color: CeosColors.lightTextSecondary),
              ),
              const SizedBox(height: 14),

              Card(
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CeosColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.system_update_rounded, color: CeosColors.primary),
                  ),
                  title: Text(
                    'Versión de la App: v${AppUpdateService.currentVersion}',
                    style: CeosTheme.heading(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Toca para comprobar actualizaciones en el servidor',
                    style: CeosTheme.body(fontSize: 12, color: CeosColors.lightTextMuted),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => AppUpdateService.checkForUpdates(context, showNoUpdateMessage: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
