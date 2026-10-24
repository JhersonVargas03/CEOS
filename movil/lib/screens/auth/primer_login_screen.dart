import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/theme/ceos_colors.dart';
import '../../core/theme/ceos_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/storage_provider.dart';
import '../../widgets/input_codigo_otp.dart';
import '../../widgets/stepper_progreso.dart';
import '../../widgets/validador_password_en_vivo.dart';

class PrimerLoginScreen extends ConsumerStatefulWidget {
  const PrimerLoginScreen({super.key});

  @override
  ConsumerState<PrimerLoginScreen> createState() => _PrimerLoginScreenState();
}

class _PrimerLoginScreenState extends ConsumerState<PrimerLoginScreen> {
  int _pasoActual = 1;
  bool _isLoading = false;
  String? _errorMessage;

  // Paso 1: Contraseña
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  String? _nuevaPassword;

  // Paso 2: Telegram
  String? _telegramLink;
  bool _telegramVinculado = false;

  // Paso 3: Teléfono y OTP
  final _telefonoController = TextEditingController();
  bool _otpEnviado = false;
  String _codigoOtp = '';
  int _segundosRestantes = 0;
  Timer? _timerReenvio;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _telefonoController.dispose();
    _timerReenvio?.cancel();
    super.dispose();
  }

  void _iniciarCuentaRegresiva() {
    setState(() {
      _segundosRestantes = 60;
    });
    _timerReenvio?.cancel();
    _timerReenvio = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_segundosRestantes > 0) {
        setState(() {
          _segundosRestantes--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  // --- Acciones de Pasos ---
  Future<void> _completarPaso1Password() async {
    final pwd = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (pwd != confirm) {
      setState(() => _errorMessage = 'Las contraseñas no coinciden');
      return;
    }

    if (pwd.length < 8) {
      setState(() => _errorMessage = 'La contraseña debe tener al menos 8 caracteres');
      return;
    }

    if (!RegExp(r'[A-Z]').hasMatch(pwd) ||
        !RegExp(r'[a-z]').hasMatch(pwd) ||
        !RegExp(r'[0-9]').hasMatch(pwd) ||
        !RegExp(r'[^A-Za-z0-9]').hasMatch(pwd)) {
      setState(() => _errorMessage = 'La contraseña no cumple con todos los requisitos de seguridad');
      return;
    }

    setState(() {
      _nuevaPassword = pwd;
      _errorMessage = null;
      _isLoading = false;
      _pasoActual = 2;
    });
    _cargarInfoTelegram();
  }

  Future<void> _cargarInfoTelegram() async {
    try {
      final repo = ref.read(authRepositoryProvider);
      final data = await repo.primerLoginVincularTelegram();
      setState(() {
        _telegramLink = data['deep_link'] as String? ?? data['bot_url'] as String? ?? 'https://t.me/Ceos_Clibot';
        _telegramVinculado = data['vinculado'] as bool? ?? false;
      });
    } catch (_) {}
  }


  Future<void> _verificarTelegram() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      // En desarrollo local sin webhook: procesar mensajes pendientes de Telegram primero
      await repo.telegramProcesarUpdates();
      // Ahora verificar si ya quedó vinculado en el backend
      final user = await repo.obtenerPerfil();
      if (user.telegramVinculado) {
        // La contraseña se cambia sólo cuando la vinculación a Telegram es confirmada
        if (_nuevaPassword != null && _nuevaPassword!.isNotEmpty) {
          try {
            await repo.primerLoginCambiarPassword(passwordNueva: _nuevaPassword!);
          } catch (_) {
            // Continuar si ya se actualizó previamente
          }
        }
        setState(() {
          _telegramVinculado = true;
          _pasoActual = 3;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Aún no detectamos la vinculación. Asegúrate de abrir el enlace del bot y enviar /start.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al verificar Telegram: $e';
        _isLoading = false;
      });
    }
  }


  Future<void> _enviarOtpTelefono() async {
    final raw = _telefonoController.text.trim();
    if (raw.isEmpty) {
      setState(() => _errorMessage = 'Ingresa tu número de celular o teléfono');
      return;
    }
    if (raw.length != 8) {
      setState(() => _errorMessage = 'El número debe tener exactamente 8 dígitos');
      return;
    }
    if (!RegExp(r'^[23467]').hasMatch(raw)) {
      setState(() => _errorMessage = 'Debe comenzar con 6 o 7 (celular) o 2, 3, 4 (fijo)');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      final telNormalizado = '+591$raw';
      await repo.primerLoginEnviarOtpTelefono(telefono: telNormalizado);
      setState(() {
        _otpEnviado = true;
        _isLoading = false;
      });
      _iniciarCuentaRegresiva();
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

  Future<void> _confirmarOtpYFinalizar() async {
    if (_codigoOtp.length != 6) {
      setState(() => _errorMessage = 'Ingresa el código completo de 6 dígitos');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.primerLoginConfirmarOtpTelefono(codigoOtp: _codigoOtp);
      await ref.read(authNotifierProvider.notifier).completeFirstLogin();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración Inicial Obligatoria'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StepperProgreso(
                pasoActual: _pasoActual,
                totalPasos: 3,
                titulosPasos: const [
                  'Nueva Contraseña',
                  'Vincular Telegram',
                  'Confirmar Teléfono',
                ],
              ),
              const SizedBox(height: 24),

              // Mensaje de Error si aplica
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
                    style: CeosTheme.body(
                      fontSize: 13,
                      color: CeosColors.statusDanger,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Contenido según Paso Actual
              if (_pasoActual == 1) _buildPaso1(),
              if (_pasoActual == 2) _buildPaso2(),
              if (_pasoActual == 3) _buildPaso3(),
            ],
          ),
        ),
      ),
    );
  }

  // --- Paso 1: Cambiar contraseña ---
  Widget _buildPaso1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Define tu contraseña permanente',
          style: CeosTheme.heading(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Por seguridad de la clínica, debes cambiar tu clave temporal antes de comenzar a operar.',
          style: CeosTheme.body(fontSize: 13, color: CeosColors.lightTextSecondary),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Nueva contraseña',
            prefixIcon: const Icon(PhosphorIconsRegular.lock),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? PhosphorIconsRegular.eye : PhosphorIconsRegular.eyeSlash),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscurePassword,
          decoration: const InputDecoration(
            labelText: 'Confirmar nueva contraseña',
            prefixIcon: Icon(PhosphorIconsRegular.lockKey),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        ValidadorPasswordEnVivo(password: _passwordController.text),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _completarPaso1Password,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Continuar a Telegram'),
        ),
      ],
    );
  }

  // --- Paso 2: Vincular Telegram ---
  Widget _buildPaso2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Vincula tu cuenta con Telegram',
          style: CeosTheme.heading(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Recibirás alertas críticas de stock, notificaciones de solicitudes y códigos de seguridad directamente en Telegram.',
          style: CeosTheme.body(fontSize: 13, color: CeosColors.lightTextSecondary),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CeosColors.areaOdontologiaLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CeosColors.areaOdontologia.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              const Icon(
                PhosphorIconsFill.telegramLogo,
                size: 48,
                color: CeosColors.areaOdontologia,
              ),
              const SizedBox(height: 12),
              Text(
                'Bot Ceos (@Ceos_Clibot)',
                style: CeosTheme.heading(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Abre el bot @Ceos_Clibot en Telegram y presiona /start para vincular tu cuenta.',
                style: CeosTheme.body(
                  fontSize: 13,
                  color: CeosColors.lightTextSecondary,
                ),
                textAlign: TextAlign.center,
              ),

            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          icon: const Icon(PhosphorIconsRegular.arrowSquareOut),
          label: const Text('Abrir Bot en Telegram'),
          onPressed: _abrirTelegramLink,
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _isLoading ? null : _verificarTelegram,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Ya envié /start, Verificar'),
        ),
      ],
    );
  }

  Future<void> _abrirTelegramLink() async {
    final link = _telegramLink;
    if (link == null || link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generando enlace de vinculación, intenta en un momento...')),
      );
      return;
    }

    try {
      final uri = Uri.parse(link);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enlace Telegram: $link')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enlace Telegram: $link')),
        );
      }
    }
  }

  // --- Paso 3: Confirmar Teléfono y OTP ---
  Widget _buildPaso3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Verifica tu número de teléfono',
          style: CeosTheme.heading(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Utilizado para recuperación de cuenta en caso de emergencias fuera de la clínica.',
          style: CeosTheme.body(fontSize: 13, color: CeosColors.lightTextSecondary),
        ),
        const SizedBox(height: 20),
        if (!_otpEnviado) ...[
          TextField(
            controller: _telefonoController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            decoration: InputDecoration(
              labelText: 'Número de celular / teléfono',
              hintText: '71234567',
              prefixIcon: const Icon(PhosphorIconsRegular.phone),
              prefixText: '+591 ',
              prefixStyle: CeosTheme.heading(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: CeosColors.areaOdontologia,
              ),
              helperText: '8 dígitos (Bolivia)',
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isLoading ? null : _enviarOtpTelefono,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Enviar Código de Verificación'),
          ),
        ] else ...[
          Text(
            'Ingresa el código de 6 dígitos enviado a +591 ${_telefonoController.text}:',
            style: CeosTheme.body(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          InputCodigoOTP(
            onCompleted: (code) {
              setState(() => _codigoOtp = code);
            },
            onChanged: (code) {
              setState(() => _codigoOtp = code);
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _segundosRestantes > 0 ? null : _enviarOtpTelefono,
                child: Text(
                  _segundosRestantes > 0
                      ? 'Reenviar en ${_segundosRestantes}s'
                      : 'Reenviar código',
                  style: CeosTheme.dataMono(
                    fontSize: 13,
                    color: _segundosRestantes > 0
                        ? CeosColors.lightTextMuted
                        : CeosColors.areaOdontologia,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _otpEnviado = false),
                child: Text(
                  'Cambiar número',
                  style: CeosTheme.body(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading || _codigoOtp.length != 6 ? null : _confirmarOtpYFinalizar,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Confirmar y Entrar al Sistema'),
          ),
        ],
      ],
    );
  }
}
