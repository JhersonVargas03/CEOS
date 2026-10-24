import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/theme/ceos_colors.dart';
import '../../core/theme/ceos_theme.dart';
import '../../models/admin_models.dart';
import '../../providers/storage_provider.dart';

class CrearUsuarioScreen extends ConsumerStatefulWidget {
  const CrearUsuarioScreen({super.key});

  @override
  ConsumerState<CrearUsuarioScreen> createState() => _CrearUsuarioScreenState();
}

class _CrearUsuarioScreenState extends ConsumerState<CrearUsuarioScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _correoController = TextEditingController();
  final _telefonoController = TextEditingController();

  List<RolModel> _roles = [];
  final List<int> _rolesSeleccionados = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _cargarRoles();
  }

  Future<void> _cargarRoles() async {
    try {
      final repo = ref.read(adminRepositoryProvider);
      final list = await repo.obtenerRoles();
      setState(() => _roles = list);
    } catch (_) {}
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _correoController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  Future<void> _crearUsuario() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(adminRepositoryProvider);
      final rawTel = _telefonoController.text.trim();
      final telefonoNormalizado = rawTel.isNotEmpty ? '+591$rawTel' : null;

      final res = await repo.crearUsuario(
        username: _usernameController.text.trim(),
        correoInterno: _correoController.text.trim(),
        telefono: telefonoNormalizado,
        rolesIds: _rolesSeleccionados.isNotEmpty ? _rolesSeleccionados : null,
      );

      final tempPass = res['password_temporal'] as String? ?? res['password'] as String? ?? 'Ceos.2026';
      final username = res['username'] as String? ?? _usernameController.text.trim();

      if (mounted) {
        context.pushReplacement(
          '/admin/usuarios/credenciales-generadas',
          extra: {
            'username': username,
            'password_temporal': tempPass,
          },
        );
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
          onPressed: () => context.canPop() ? context.pop() : context.go('/admin'),
        ),
        title: const Text('Crear Nuevo Usuario'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CeosColors.statusDangerLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(_errorMessage!, style: CeosTheme.body(color: CeosColors.statusDanger)),
                  ),
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de usuario *',
                    hintText: 'ej. doctor.garcia',
                    prefixIcon: Icon(PhosphorIconsRegular.user),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Ingresa el nombre de usuario' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _correoController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo interno de la clínica *',
                    hintText: 'ej. d.garcia@ceos.local',
                    prefixIcon: Icon(PhosphorIconsRegular.envelope),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Ingresa el correo' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _telefonoController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Teléfono / Celular (Bolivia - Opcional)',
                    hintText: '71234567',
                    prefixIcon: const Icon(PhosphorIconsRegular.phone),
                    prefixText: '+591 ',
                    prefixStyle: CeosTheme.heading(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: CeosColors.areaOdontologia,
                    ),
                    helperText: '8 dígitos sin código de país (ej. 7XXXXXXX o 6XXXXXXX)',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return null;
                    final limpio = val.trim();
                    if (limpio.length != 8) {
                      return 'El número debe tener exactamente 8 dígitos';
                    }
                    if (!RegExp(r'^[23467]').hasMatch(limpio)) {
                      return 'Debe comenzar con 6 o 7 (celular) o 2, 3, 4 (fijo)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                Text('Roles a Asignar', style: CeosTheme.heading(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                ..._roles.map((r) {
                  final isChecked = _rolesSeleccionados.contains(r.id);
                  return CheckboxListTile(
                    title: Text(r.nombre, style: CeosTheme.heading(fontSize: 14)),
                    subtitle: Text(r.descripcion, style: CeosTheme.body(fontSize: 12)),
                    value: isChecked,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _rolesSeleccionados.add(r.id);
                        } else {
                          _rolesSeleccionados.remove(r.id);
                        }
                      });
                    },
                  );
                }),

                const SizedBox(height: 28),

                ElevatedButton(
                  onPressed: _isLoading ? null : _crearUsuario,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Crear Usuario y Generar Credenciales'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
