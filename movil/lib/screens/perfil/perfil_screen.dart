import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/theme/ceos_colors.dart';
import '../../core/theme/ceos_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/storage_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/chip_rol_activo.dart';
import '../../widgets/validador_password_en_vivo.dart';

class PerfilScreen extends ConsumerStatefulWidget {
  const PerfilScreen({super.key});

  @override
  ConsumerState<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends ConsumerState<PerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _nombreController;
  late TextEditingController _telefonoController;

  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _usernameController = TextEditingController(text: user?.username ?? '');
    _nombreController = TextEditingController(text: user?.nombreCompleto ?? '');

    // Si el teléfono viene con +591, mostrar solo los 8 dígitos locales en el campo
    var tel = user?.telefono ?? '';
    if (tel.startsWith('+591')) {
      tel = tel.substring(4);
    } else if (tel.startsWith('591')) {
      tel = tel.substring(3);
    }
    _telefonoController = TextEditingController(text: tel);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nombreController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  Future<void> _guardarPerfil() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final username = _usernameController.text.trim().toLowerCase();
    final nombre = _nombreController.text.trim();
    final telLocal = _telefonoController.text.trim();

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final updatedUser = await authRepo.actualizarPerfil(
        username: username,
        nombreCompleto: nombre,
        telefono: telLocal.isNotEmpty ? telLocal : '',
      );

      // Actualizar estado en Riverpod
      ref.read(authNotifierProvider.notifier).actualizarUsuarioLocal(updatedUser);

      if (mounted) {
        setState(() {
          _isSaving = false;
          _successMessage = 'Perfil y nombre de usuario actualizados correctamente.';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tus datos de perfil han sido actualizados.'),
            backgroundColor: CeosColors.statusSuccess,
          ),
        );
      }
    } on AppException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al actualizar perfil: $e';
          _isSaving = false;
        });
      }
    }
  }

  void _mostrarDialogoCambiarPassword() {
    final actualCtrl = TextEditingController();
    final nuevaCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final dialogFormKey = GlobalKey<FormState>();
    bool obscureActual = true;
    bool obscureNueva = true;
    bool obscureConfirm = true;
    bool isChanging = false;
    String? dialogError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(PhosphorIconsRegular.lockKey, color: CeosColors.areaOdontologia),
              SizedBox(width: 8),
              Text('Cambiar Contraseña'),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: dialogFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (dialogError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: CeosColors.statusDangerLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        dialogError!,
                        style: CeosTheme.body(fontSize: 12, color: CeosColors.statusDanger),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: actualCtrl,
                    obscureText: obscureActual,
                    decoration: InputDecoration(
                      labelText: 'Contraseña Actual *',
                      prefixIcon: const Icon(PhosphorIconsRegular.key),
                      suffixIcon: IconButton(
                        icon: Icon(obscureActual ? PhosphorIconsRegular.eye : PhosphorIconsRegular.eyeSlash),
                        onPressed: () => setDialogState(() => obscureActual = !obscureActual),
                      ),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Ingresa tu contraseña actual' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nuevaCtrl,
                    obscureText: obscureNueva,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Nueva Contraseña *',
                      prefixIcon: const Icon(PhosphorIconsRegular.lock),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNueva ? PhosphorIconsRegular.eye : PhosphorIconsRegular.eyeSlash),
                        onPressed: () => setDialogState(() => obscureNueva = !obscureNueva),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Ingresa una nueva contraseña';
                      if (v == actualCtrl.text) {
                        return 'La nueva contraseña no puede ser igual a la actual';
                      }
                      if (!ValidadorPasswordEnVivo.validar(v).esValida) {
                        return 'Debe cumplir los 5 requisitos de seguridad';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  ValidadorPasswordEnVivo(password: nuevaCtrl.text),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmCtrl,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirmar Nueva Contraseña *',
                      prefixIcon: const Icon(PhosphorIconsRegular.lockSimple),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm ? PhosphorIconsRegular.eye : PhosphorIconsRegular.eyeSlash),
                        onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                      ),
                    ),
                    validator: (v) {
                      if (v != nuevaCtrl.text) return 'Las contraseñas no coinciden';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isChanging ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isChanging
                  ? null
                  : () async {
                      if (!dialogFormKey.currentState!.validate()) return;
                      setDialogState(() {
                        isChanging = true;
                        dialogError = null;
                      });

                      try {
                        final authRepo = ref.read(authRepositoryProvider);
                        await authRepo.actualizarPerfil(
                          passwordActual: actualCtrl.text,
                          passwordNueva: nuevaCtrl.text,
                        );

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Contraseña cambiada exitosamente.'),
                              backgroundColor: CeosColors.statusSuccess,
                            ),
                          );
                        }
                      } on AppException catch (e) {
                        setDialogState(() {
                          dialogError = e.message;
                          isChanging = false;
                        });
                      } catch (e) {
                        setDialogState(() {
                          dialogError = e.toString();
                          isChanging = false;
                        });
                      }
                    },
              child: isChanging
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Actualizar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeNotifierProvider);

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowsClockwise),
            tooltip: 'Actualizar información',
            onPressed: () async {
              try {
                final authRepo = ref.read(authRepositoryProvider);
                final updated = await authRepo.obtenerPerfil();
                ref.read(authNotifierProvider.notifier).actualizarUsuarioLocal(updated);
                setState(() {
                  _nombreController.text = updated.nombreCompleto;
                  var tel = updated.telefono;
                  if (tel.startsWith('+591')) tel = tel.substring(4);
                  _telefonoController.text = tel;
                });
              } catch (_) {}
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tarjeta de Cabecera con Avatar
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: CeosColors.areaOdontologiaLight,
                        child: Text(
                          user.nombreMostrado.isNotEmpty
                              ? user.nombreMostrado[0].toUpperCase()
                              : 'U',
                          style: CeosTheme.heading(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: CeosColors.areaOdontologia,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user.nombreMostrado,
                        style: CeosTheme.heading(fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@${user.username} • ${user.correoInterno}',
                        style: CeosTheme.body(fontSize: 13, color: CeosColors.lightTextSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChipRolActivo(
                            rol: user.rolPrincipal,
                            esSuperadmin: user.esSuperadmin,
                          ),
                          // Badge Telegram
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: user.telegramVinculado
                                  ? CeosColors.statusSuccessLight
                                  : CeosColors.statusWarningLight,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: user.telegramVinculado
                                    ? CeosColors.statusSuccess.withValues(alpha: 0.5)
                                    : CeosColors.statusWarning.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  user.telegramVinculado
                                      ? PhosphorIconsFill.telegramLogo
                                      : PhosphorIconsRegular.warningCircle,
                                  size: 14,
                                  color: user.telegramVinculado
                                      ? CeosColors.statusSuccess
                                      : CeosColors.statusWarning,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  user.telegramVinculado ? 'Telegram Vinculado' : 'Telegram Sin Vincular',
                                  style: CeosTheme.body(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: user.telegramVinculado
                                        ? CeosColors.statusSuccess
                                        : CeosColors.statusWarning,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Alertas de Estado
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CeosColors.statusDangerLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: CeosColors.statusDanger.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: CeosTheme.body(fontSize: 13, color: CeosColors.statusDanger),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_successMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CeosColors.statusSuccessLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: CeosColors.statusSuccess.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _successMessage!,
                      style: CeosTheme.body(fontSize: 13, color: CeosColors.statusSuccess),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Sección: Información Personal Editable
                Text(
                  'Datos Personales',
                  style: CeosTheme.heading(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: CeosColors.areaOdontologia.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: CeosColors.areaOdontologia.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(PhosphorIconsRegular.info, size: 20, color: CeosColors.areaOdontologia),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Para iniciar sesión puedes usar tu usuario (@${user.username}) o tu correo (${user.correoInterno}).',
                          style: CeosTheme.body(fontSize: 12, color: CeosColors.lightTextSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre de Usuario (@username) *',
                            hintText: 'ej. doctor_perez',
                            prefixIcon: Icon(PhosphorIconsRegular.at),
                            helperText: 'Identificador para iniciar sesión (3 a 30 caracteres)',
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Ingresa un nombre de usuario';
                            }
                            final limpio = v.trim().toLowerCase();
                            if (limpio.length < 3) {
                              return 'El usuario debe tener al menos 3 caracteres';
                            }
                            if (limpio.length > 30) {
                              return 'El usuario no puede exceder los 30 caracteres';
                            }
                            if (!RegExp(r'^[a-z0-9._]+$').hasMatch(limpio)) {
                              return 'Solo letras minúsculas, números, puntos (.) y guiones bajos (_)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nombreController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre Completo / Título',
                            hintText: 'Ej. Dr. Carlos Fernández',
                            prefixIcon: Icon(PhosphorIconsRegular.user),
                            helperText: 'Tu nombre y apellido mostrado en la app',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _telefonoController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Teléfono de Contacto (Bolivia)',
                            hintText: '71234567',
                            prefixIcon: Icon(PhosphorIconsRegular.phone),
                            prefixText: '+591 ',
                          ),
                          validator: (v) {
                            if (v != null && v.trim().isNotEmpty) {
                              final limpio = v.trim().replaceAll(RegExp(r'\s+'), '');
                              if (!RegExp(r'^[23467]\d{7}$').hasMatch(limpio)) {
                                return 'Número boliviano inválido (8 dígitos iniciando con 6, 7, 2, 3 o 4)';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _isSaving ? null : _guardarPerfil,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(PhosphorIconsRegular.floppyDisk),
                          label: const Text('Guardar Cambios'),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Sección: Seguridad y Credenciales
                Text(
                  'Seguridad de la Cuenta',
                  style: CeosTheme.heading(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: CeosColors.areaOdontologia.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            PhosphorIconsRegular.password,
                            color: CeosColors.areaOdontologia,
                          ),
                        ),
                        title: Text(
                          'Cambiar Contraseña',
                          style: CeosTheme.heading(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Actualiza tu clave de acceso al sistema',
                          style: CeosTheme.body(fontSize: 12, color: CeosColors.lightTextSecondary),
                        ),
                        trailing: const Icon(PhosphorIconsRegular.caretRight, size: 16),
                        onTap: _mostrarDialogoCambiarPassword,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            PhosphorIconsRegular.telegramLogo,
                            color: Colors.blue,
                          ),
                        ),
                        title: Text(
                          'Notificaciones Telegram',
                          style: CeosTheme.heading(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          user.telegramVinculado
                              ? 'Vinculado y listo para recibir alertas'
                              : 'Revisa la vinculación con el bot de Telegram',
                          style: CeosTheme.body(fontSize: 12, color: CeosColors.lightTextSecondary),
                        ),
                        trailing: Icon(
                          user.telegramVinculado
                              ? PhosphorIconsFill.checkCircle
                              : PhosphorIconsRegular.warningCircle,
                          color: user.telegramVinculado ? CeosColors.statusSuccess : CeosColors.statusWarning,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Sección: Apariencia del Sistema (Tema Claro / Oscuro / Sistema)
                Text(
                  'Apariencia y Tema',
                  style: CeosTheme.heading(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: context.isDarkMode ? 0.2 : 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: CeosColors.areaOdontologia.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              themeMode == ThemeMode.dark
                                  ? PhosphorIconsFill.moon
                                  : themeMode == ThemeMode.light
                                      ? PhosphorIconsFill.sun
                                      : PhosphorIconsFill.deviceMobile,
                              color: CeosColors.areaOdontologia,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Modo Visual',
                                  style: CeosTheme.heading(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  'Personaliza el contraste y la iluminación de la app',
                                  style: CeosTheme.body(fontSize: 12, color: context.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ThemeMode>(
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.light,
                              icon: Icon(PhosphorIconsRegular.sun, size: 16),
                              label: Text('Claro'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              icon: Icon(PhosphorIconsRegular.moon, size: 16),
                              label: Text('Oscuro'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.system,
                              icon: Icon(PhosphorIconsRegular.deviceMobile, size: 16),
                              label: Text('Sistema'),
                            ),
                          ],
                          selected: {themeMode},
                          onSelectionChanged: (Set<ThemeMode> newSelection) {
                            ref.read(themeNotifierProvider.notifier).setThemeMode(newSelection.first);
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Botón Cerrar Sesión
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CeosColors.statusDanger,
                    side: const BorderSide(color: CeosColors.statusDanger),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(PhosphorIconsRegular.signOut),
                  label: const Text('Cerrar Sesión'),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('¿Cerrar Sesión?'),
                        content: const Text('Tendrás que ingresar tus credenciales para volver a entrar.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancelar'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: CeosColors.statusDanger,
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              ref.read(authNotifierProvider.notifier).logout();
                              context.go('/login');
                            },
                            child: const Text('Cerrar Sesión'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
