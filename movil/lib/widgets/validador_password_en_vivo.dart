import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/theme/ceos_colors.dart';
import '../core/theme/ceos_theme.dart';

class PasswordValidacion {
  final bool tieneMinimo8;
  final bool tieneMayuscula;
  final bool tieneMinuscula;
  final bool tieneNumero;
  final bool tieneSimbolo;

  const PasswordValidacion({
    required this.tieneMinimo8,
    required this.tieneMayuscula,
    required this.tieneMinuscula,
    required this.tieneNumero,
    required this.tieneSimbolo,
  });

  bool get esValida =>
      tieneMinimo8 && tieneMayuscula && tieneMinuscula && tieneNumero && tieneSimbolo;
}

class ValidadorPasswordEnVivo extends StatelessWidget {
  final String password;

  const ValidadorPasswordEnVivo({
    super.key,
    required this.password,
  });

  static PasswordValidacion validar(String password) {
    return PasswordValidacion(
      tieneMinimo8: password.length >= 8,
      tieneMayuscula: password.contains(RegExp(r'[A-Z]')),
      tieneMinuscula: password.contains(RegExp(r'[a-z]')),
      tieneNumero: password.contains(RegExp(r'[0-9]')),
      tieneSimbolo: password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')),
    );
  }

  bool get tieneMinimo8 => password.length >= 8;
  bool get tieneMayuscula => password.contains(RegExp(r'[A-Z]'));
  bool get tieneMinuscula => password.contains(RegExp(r'[a-z]'));
  bool get tieneNumero => password.contains(RegExp(r'[0-9]'));
  bool get tieneEspecial => password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

  bool get esValida => validar(password).esValida;

  Widget _buildCheckItem(String label, bool cumple) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Icon(
            cumple ? PhosphorIconsFill.checkCircle : PhosphorIconsRegular.circle,
            size: 16,
            color: cumple ? CeosColors.statusSuccess : CeosColors.lightTextMuted,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: CeosTheme.body(
              fontSize: 12,
              color: cumple ? CeosColors.statusSuccess : CeosColors.lightTextSecondary,
              fontWeight: cumple ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: esValida
              ? CeosColors.statusSuccess.withValues(alpha: 0.4)
              : Colors.grey.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Requisitos de contraseña:',
            style: CeosTheme.heading(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          _buildCheckItem('Mínimo 8 caracteres', tieneMinimo8),
          _buildCheckItem('Al menos una letra mayúscula (A-Z)', tieneMayuscula),
          _buildCheckItem('Al menos una letra minúscula (a-z)', tieneMinuscula),
          _buildCheckItem('Al menos un número (0-9)', tieneNumero),
          _buildCheckItem('Al menos un carácter especial (!@#\$%...)', tieneEspecial),
        ],
      ),
    );
  }
}
