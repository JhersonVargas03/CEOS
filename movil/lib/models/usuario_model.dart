class UsuarioModel {
  final int id;
  final String username;
  final String correoInterno;
  final String nombreCompleto;
  final String telefono;
  final bool activo;
  final bool primerLoginCompletado;
  final bool telegramVinculado;
  final bool telefonoVerificado;
  final int sessionVersion;
  final List<String> roles;
  final List<String> permisos;

  const UsuarioModel({
    required this.id,
    required this.username,
    required this.correoInterno,
    this.nombreCompleto = '',
    this.telefono = '',
    this.activo = true,
    this.primerLoginCompletado = true,
    this.telegramVinculado = false,
    this.telefonoVerificado = false,
    this.sessionVersion = 1,
    this.roles = const [],
    this.permisos = const [],
  });

  bool get esSuperadmin => roles.any((r) => r.toLowerCase() == 'superadmin');

  bool tienePermiso(String permiso) {
    if (esSuperadmin) return true;
    return permisos.contains(permiso);
  }

  String get rolPrincipal {
    if (esSuperadmin) return 'Superadmin';
    if (roles.isNotEmpty) return roles.first;
    return 'Personal';
  }

  String get nombreMostrado {
    if (nombreCompleto.trim().isNotEmpty) return nombreCompleto.trim();
    return username.isNotEmpty ? username : correoInterno;
  }

  factory UsuarioModel.fromJson(Map<String, dynamic> json) {
    return UsuarioModel(
      id: json['id'] as int? ?? 0,
      username: json['username'] as String? ?? '',
      correoInterno: json['correo_interno'] as String? ?? '',
      nombreCompleto: json['nombre_completo'] as String? ?? '',
      telefono: json['telefono'] as String? ?? '',
      activo: json['activo'] as bool? ?? true,
      primerLoginCompletado: json['primer_login_completado'] as bool? ?? true,
      telegramVinculado: json['telegram_vinculado'] as bool? ?? false,
      telefonoVerificado: json['telefono_verificado'] as bool? ?? false,
      sessionVersion: json['session_version'] as int? ?? 1,
      roles: (json['roles'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      permisos: (json['permisos'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'correo_interno': correoInterno,
      'nombre_completo': nombreCompleto,
      'telefono': telefono,
      'activo': activo,
      'primer_login_completado': primerLoginCompletado,
      'telegram_vinculado': telegramVinculado,
      'telefono_verificado': telefonoVerificado,
      'session_version': sessionVersion,
      'roles': roles,
      'permisos': permisos,
    };
  }

  UsuarioModel copyWith({
    int? id,
    String? username,
    String? correoInterno,
    String? nombreCompleto,
    String? telefono,
    bool? activo,
    bool? primerLoginCompletado,
    bool? telegramVinculado,
    bool? telefonoVerificado,
    int? sessionVersion,
    List<String>? roles,
    List<String>? permisos,
  }) {
    return UsuarioModel(
      id: id ?? this.id,
      username: username ?? this.username,
      correoInterno: correoInterno ?? this.correoInterno,
      nombreCompleto: nombreCompleto ?? this.nombreCompleto,
      telefono: telefono ?? this.telefono,
      activo: activo ?? this.activo,
      primerLoginCompletado: primerLoginCompletado ?? this.primerLoginCompletado,
      telegramVinculado: telegramVinculado ?? this.telegramVinculado,
      telefonoVerificado: telefonoVerificado ?? this.telefonoVerificado,
      sessionVersion: sessionVersion ?? this.sessionVersion,
      roles: roles ?? this.roles,
      permisos: permisos ?? this.permisos,
    );
  }
}
