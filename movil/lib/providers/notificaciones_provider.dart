import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/admin_models.dart';
import '../models/inventario_models.dart';
import 'auth_provider.dart';
import 'storage_provider.dart';

final notificacionesProvider = FutureProvider<List<NotificacionModel>>((ref) async {
  final repo = ref.watch(notificacionesRepositoryProvider);
  return await repo.obtenerNotificaciones();
});

final contadorNoLeidasProvider = Provider<int>((ref) {
  final notifsAsync = ref.watch(notificacionesProvider);
  return notifsAsync.maybeWhen(
    data: (list) => list.where((n) => !n.leida).length,
    orElse: () => 0,
  );
});

final historialRecienteProvider = FutureProvider<List<MovimientoHistorialModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.id == 0) return [];

  final repo = ref.watch(notificacionesRepositoryProvider);
  return await repo.obtenerHistorialUsuario(user.id);
});
