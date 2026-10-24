import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/theme/ceos_colors.dart';
import '../../core/theme/ceos_theme.dart';
import '../../providers/storage_provider.dart';
import '../../widgets/input_codigo_otp.dart';
import '../../widgets/stepper_progreso.dart';
import '../../widgets/validador_password_en_vivo.dart';

class RecuperarPasswordScreen extends ConsumerStatefulWidget {
  const RecuperarPasswordScreen({super.key});

  @override
  ConsumerState<RecuperarPasswordScreen> createState() => _RecuperarPasswordScreenState();
}

class _RecuperarPasswordScreenState extends ConsumerState<RecuperarPasswordScreen> {
  int _pasoActual = 1;
  bool _isLoading = false;
  String? _errorMessage;

  // Paso 1
  final _identificadorController = TextEditingController();

  // Paso 2
  String _codigoOtp = '';
  int _intentosRestantes = 3;

  // Paso 3
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _identificadorController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _solicitarCodigo() async {
    final ident = _identificadorController.text.trim();
    if (ident.isEmpty) {
      setState(() => _errorMessage = 'Ingresa tu usuario o correo interno');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.solicitarRecuperacionPassword(identificador: ident);
      setState(() {
        _pasoActual = 2;
        _isLoading = false;
      });
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

  Future<void> _verificarCodigo() async {
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
      final res = await repo.verificarCodigoRecuperacion(
        identificador: _identificadorController.text.trim(),
        codigoOtp: _codigoOtp,
      );

      if (res['intentos_restantes'] != null) {
        _intentosRestantes = res['intentos_restantes'] as int;
      }

      setState(() {
        _pasoActual = 3;
        _isLoading = false;
      });
    } on AppException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
        if (_intentosRestantes > 1) _intentosRestantes--;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _cambiarPasswordYFinalizar() async {
    final pwd = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (!ValidadorPasswordEnVivo.validar(pwd).esValida) {
      setState(() => _errorMessage = 'La contraseña debe cumplir todos los requisitos de seguridad');
      return;
    }

    if (pwd != confirm) {
      setState(() => _errorMessage = 'Las contraseñas no coinciden');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.nuevaPasswordRecuperacion(
        identificador: _identificadorController.text.trim(),
        codigoOtp: _codigoOtp,
        passwordNueva: pwd,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contraseña restablecida exitosamente. Inicia sesión.'),
            backgroundColor: CeosColors.statusSuccess,
          ),
        );
        context.go('/login');
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          tooltip: 'Atrás',
          onPressed: () => context.canPop() ? context.pop() : context.go('/login'),
        ),
        title: const Text('Recuperar Contraseña'),
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
                  'Solicitar',
                  'Verificar',
                  'Nueva Clave',
                ],
              ),
              const SizedBox(height: 24),

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

              if (_pasoActual == 1) _buildPaso1(),
              if (_pasoActual == 2) _buildPaso2(),
              if (_pasoActual == 3) _buildPaso3(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaso1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Solicitud de Recuperación',
          style: CeosTheme.heading(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Ingresa tu usuario o correo. Si la cuenta existe, te enviaremos un código de seguridad por tu canal vinculado.',
          style: CeosTheme.body(fontSize: 13, color: CeosColors.lightTextSecondary),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _identificadorController,
          decoration: const InputDecoration(
            labelText: 'Usuario o correo interno',
            prefixIcon: Icon(PhosphorIconsRegular.user),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _solicitarCodigo,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Enviar Código de Seguridad'),
        ),
      ],
    );
  }

  Widget _buildPaso2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Código de Seguridad',
          style: CeosTheme.heading(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Ingresa el código de 6 dígitos que recibiste en Telegram / Mensajería.',
          style: CeosTheme.body(fontSize: 13, color: CeosColors.lightTextSecondary),
        ),
        const SizedBox(height: 20),
        InputCodigoOTP(
          onCompleted: (code) {
            setState(() => _codigoOtp = code);
          },
          onChanged: (code) {
            setState(() => _codigoOtp = code);
          },
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Intentos restantes: $_intentosRestantes',
            style: CeosTheme.dataMono(
              fontSize: 12,
              color: _intentosRestantes <= 1
                  ? CeosColors.statusDanger
                  : CeosColors.lightTextMuted,
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading || _codigoOtp.length != 6 ? null : _verificarCodigo,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Verificar Código'),
        ),
      ],
    );
  }

  Widget _buildPaso3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Nueva Contraseña',
          style: CeosTheme.heading(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Define una nueva clave segura para tu cuenta.',
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
          onPressed: _isLoading ? null : _cambiarPasswordYFinalizar,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Restablecer e Iniciar Sesión'),
        ),
      ],
    );
  }
}
