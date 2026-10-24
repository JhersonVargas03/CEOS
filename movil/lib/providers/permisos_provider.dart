import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/auth_repository.dart';
import 'auth_provider.dart';
import 'storage_provider.dart';

final permisosEfectivosProvider = FutureProvider<List<String>>((ref) async {
  final authState = ref.watch(authNotifierProvider);

  if (authState.user != null) {
    return authState.user!.permisos;
  }

  // If user is authenticated in storage but not yet in state, fetch directly
  final authRepo = ref.watch(authRepositoryProvider);
  try {
    final user = await authRepo.obtenerPerfil();
    return user.permisos;
  } catch (e) {
    throw Exception('Error al cargar permisos del usuario: $e');
  }
});

final esSuperadminProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.esSuperadmin ?? false;
});

final usuarioActivoProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.activo ?? true;
});
