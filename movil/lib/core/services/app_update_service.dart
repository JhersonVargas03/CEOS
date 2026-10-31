import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/env_config.dart';
import '../theme/ceos_colors.dart';

class UpdateInfo {
  final String versionActual;
  final String versionMinima;
  final String urlDescarga;
  final String notas;
  final bool obligatoria;

  UpdateInfo({
    required this.versionActual,
    required this.versionMinima,
    required this.urlDescarga,
    required this.notas,
    required this.obligatoria,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      versionActual: json['version_actual']?.toString() ?? '1.0.0',
      versionMinima: json['version_minima']?.toString() ?? '1.0.0',
      urlDescarga: json['url_descarga']?.toString() ?? '',
      notas: json['notas']?.toString() ?? 'Mejoras y correcciones generales.',
      obligatoria: json['obligatoria'] == true,
    );
  }
}

class AppUpdateService {
  AppUpdateService._();

  /// Versión actual instalada en el dispositivo
  static const String currentVersion = '1.0.0';

  static bool _checkingUpdate = false;

  /// Compara versiones semánticas (ej. "1.0.1" vs "1.0.0")
  static bool isServerNewer(String serverVersion, String localVersion) {
    try {
      // Remover sufijos como -rc1 o +1 si existen
      final cleanServer = serverVersion.split('-').first.split('+').first;
      final cleanLocal = localVersion.split('-').first.split('+').first;

      final s = cleanServer.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final l = cleanLocal.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < 3; i++) {
        final sPart = i < s.length ? s[i] : 0;
        final lPart = i < l.length ? l[i] : 0;
        if (sPart > lPart) return true;
        if (sPart < lPart) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Consulta al backend si hay una versión más reciente
  static Future<void> checkForUpdates(
    BuildContext context, {
    bool showNoUpdateMessage = false,
  }) async {
    if (_checkingUpdate) return;
    _checkingUpdate = true;

    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      final endpoint = '${EnvConfig.apiBaseUrl}/sistema/version/';
      final response = await dio.get(endpoint);

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final updateInfo = UpdateInfo.fromJson(response.data);

        final needsUpdate = isServerNewer(updateInfo.versionActual, currentVersion);

        if (needsUpdate && context.mounted) {
          _showUpdateDialog(context, updateInfo);
        } else if (showNoUpdateMessage && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tienes instalada la versión más reciente (v$currentVersion).'),
              backgroundColor: CeosColors.statusSuccess,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error consultando actualización: $e');
      }
      if (showNoUpdateMessage && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo comprobar actualizaciones en este momento.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      _checkingUpdate = false;
    }
  }

  /// Muestra el modal interactivo con notas de versión y descarga con barra de progreso
  static void _showUpdateDialog(BuildContext context, UpdateInfo info) {
    showDialog(
      context: context,
      barrierDismissible: !info.obligatoria,
      builder: (dialogContext) {
        return _UpdateDialogWidget(info: info);
      },
    );
  }
}

class _UpdateDialogWidget extends StatefulWidget {
  final UpdateInfo info;

  const _UpdateDialogWidget({required this.info});

  @override
  State<_UpdateDialogWidget> createState() => _UpdateDialogWidgetState();
}

class _UpdateDialogWidgetState extends State<_UpdateDialogWidget> {
  bool _downloading = false;
  double _progress = 0.0;
  String _statusText = '';

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _progress = 0.0;
      _statusText = 'Iniciando descarga...';
    });

    try {
      if (!kIsWeb && Platform.isAndroid) {
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/CEOS_v${widget.info.versionActual}.apk';

        final dio = Dio();
        await dio.download(
          widget.info.urlDescarga,
          filePath,
          onReceiveProgress: (received, total) {
            if (total > 0 && mounted) {
              setState(() {
                _progress = received / total;
                final mbReceived = (received / (1024 * 1024)).toStringAsFixed(1);
                final mbTotal = (total / (1024 * 1024)).toStringAsFixed(1);
                _statusText = 'Descargando: $mbReceived MB / $mbTotal MB (${(_progress * 100).toInt()}%)';
              });
            }
          },
        );

        if (mounted) {
          setState(() {
            _statusText = 'Abriendo instalador de Android...';
          });
        }

        final result = await OpenFilex.open(filePath);
        if (result.type != ResultType.done) {
          // Fallback a navegador si el instalador nativo no abre
          _launchBrowser();
        }
      } else {
        // En desktop o web abrir enlace de descarga directo
        _launchBrowser();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _statusText = 'Error en la descarga. Abriendo navegador...';
        });
      }
      _launchBrowser();
    }
  }

  Future<void> _launchBrowser() async {
    final uri = Uri.parse(widget.info.urlDescarga);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: !widget.info.obligatoria && !_downloading,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: CeosColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.system_update_rounded, color: CeosColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nueva versión de CEOS',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'v${widget.info.versionActual} disponible',
                    style: const TextStyle(fontSize: 13, color: CeosColors.primary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Novedades de esta actualización:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
              ),
              child: Text(
                widget.info.notas,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
            if (_downloading) ...[
              const SizedBox(height: 18),
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                color: CeosColors.primary,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _statusText,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (!widget.info.obligatoria && !_downloading)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Más tarde'),
            ),
          if (!_downloading)
            ElevatedButton.icon(
              onPressed: _startDownload,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Actualizar ahora'),
              style: ElevatedButton.styleFrom(
                backgroundColor: CeosColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
        ],
      ),
    );
  }
}
