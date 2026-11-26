import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/theme/ceos_colors.dart';
import '../core/theme/ceos_theme.dart';

/// Modal de escaneo de código de barras / QR con cámara y fallback manual.
class EscanerCodigoBarrasModal extends StatefulWidget {
  const EscanerCodigoBarrasModal({super.key});

  /// Abre el escáner y retorna el código leído (o null si el usuario cancela).
  static Future<String?> abrir(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const EscanerCodigoBarrasModal(),
    );
  }

  @override
  State<EscanerCodigoBarrasModal> createState() => _EscanerCodigoBarrasModalState();
}

class _EscanerCodigoBarrasModalState extends State<EscanerCodigoBarrasModal> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _procesado = false;
  bool _linternaActiva = false;
  bool _modoManual = false;
  final TextEditingController _manualController = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    _manualController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_procesado) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw != null && raw.isNotEmpty) {
        _procesado = true;
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(raw);
        return;
      }
    }
  }

  Future<void> _toggleLinterna() async {
    try {
      await _controller.toggleTorch();
      if (mounted) setState(() => _linternaActiva = !_linternaActiva);
    } catch (_) {}
  }

  void _confirmarManual() {
    final code = _manualController.text.trim();
    if (code.isNotEmpty) {
      Navigator.of(context).pop(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.72;

    return SizedBox(
      height: height,
      child: Column(
        children: [
          // Barra superior
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF14181F),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(PhosphorIconsRegular.barcode, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _modoManual ? 'Ingresar código manualmente' : 'Escanear código de barras',
                    style: CeosTheme.heading(fontSize: 16, color: Colors.white),
                  ),
                ),
                if (!_modoManual)
                  IconButton(
                    icon: Icon(
                      _linternaActiva ? PhosphorIconsFill.flashlight : PhosphorIconsRegular.flashlight,
                      color: _linternaActiva ? Colors.amber : Colors.white,
                    ),
                    tooltip: 'Linterna',
                    onPressed: _toggleLinterna,
                  ),
                IconButton(
                  icon: const Icon(PhosphorIconsRegular.x, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Área principal: cámara o ingreso manual
          Expanded(
            child: _modoManual
                ? Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _manualController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            labelText: 'Código de barras / SKU',
                            hintText: 'Ej. 7751234567890',
                            prefixIcon: Icon(PhosphorIconsRegular.barcode),
                          ),
                          onSubmitted: (_) => _confirmarManual(),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _confirmarManual,
                          icon: const Icon(PhosphorIconsRegular.magnifyingGlass),
                          label: const Text('Usar este código'),
                        ),
                      ],
                    ),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        controller: _controller,
                        onDetect: _onDetect,
                        errorBuilder: (context, error, child) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    PhosphorIconsRegular.cameraSlash,
                                    color: Colors.white70,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No se pudo acceder a la cámara.\nVerifica los permisos o ingresa el código manualmente.',
                                    textAlign: TextAlign.center,
                                    style: CeosTheme.body(color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      // Marco guía central
                      Center(
                        child: Container(
                          width: 260,
                          height: 140,
                          decoration: BoxDecoration(
                            border: Border.all(color: CeosColors.areaOdontologia, width: 2.5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 18,
                        left: 20,
                        right: 20,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Apunta al código de barras del empaque',
                              style: CeosTheme.body(fontSize: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),

          // Pie con cambio a modo manual / cámara
          Container(
            color: const Color(0xFF14181F),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => setState(() => _modoManual = !_modoManual),
                icon: Icon(
                  _modoManual ? PhosphorIconsRegular.camera : PhosphorIconsRegular.keyboard,
                  color: Colors.white,
                ),
                label: Text(
                  _modoManual ? 'Volver a usar la cámara' : 'Ingresar código manualmente',
                  style: CeosTheme.body(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
