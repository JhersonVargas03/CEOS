import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/ceos_colors.dart';
import '../../core/theme/ceos_theme.dart';

class CredencialesGeneradasScreen extends StatelessWidget {
  final String username;
  final String passwordTemporal;

  const CredencialesGeneradasScreen({
    super.key,
    required this.username,
    required this.passwordTemporal,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          tooltip: 'Atrás',
          onPressed: () => context.canPop() ? context.pop() : context.go('/admin'),
        ),
        title: const Text('Credenciales Generadas'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CeosColors.statusWarningLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CeosColors.statusWarning.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(PhosphorIconsFill.warning, color: CeosColors.statusWarning, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Copia estas credenciales ahora. Por seguridad, la contraseña temporal no se volverá a mostrar.',
                        style: CeosTheme.body(fontSize: 13, color: CeosColors.lightTextPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Usuario:', style: CeosTheme.body(color: CeosColors.lightTextSecondary)),
                    const SizedBox(height: 4),
                    Text(username, style: CeosTheme.heading(fontSize: 16, fontWeight: FontWeight.bold)),
                    const Divider(height: 24),
                    Text('Contraseña Temporal:', style: CeosTheme.body(color: CeosColors.lightTextSecondary)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            passwordTemporal,
                            style: CeosTheme.dataMono(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: CeosColors.areaOdontologia,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(PhosphorIconsRegular.copy, size: 20),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: passwordTemporal));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Contraseña copiada al portapapeles.'),
                                  backgroundColor: CeosColors.statusSuccess,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),

              ElevatedButton(
                onPressed: () {
                  context.go('/admin/usuarios');
                },
                child: const Text('Entendido, Volver a Usuarios'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
