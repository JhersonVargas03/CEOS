import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../core/storage/secure_storage_service.dart';
import '../repositories/admin_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/inventario_repository.dart';
import '../repositories/notificaciones_repository.dart';

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageServiceProvider);
  return ApiClient(
    storageService: storage,
    onSessionExpired: () {
      // Invalidate auth state upon expired session
      ref.read(sessionExpiredTriggerProvider.notifier).state++;
    },
  );
});

final sessionExpiredTriggerProvider = StateProvider<int>((ref) => 0);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  final storage = ref.watch(secureStorageServiceProvider);
  return AuthRepository(apiClient: api, storageService: storage);
});

final inventarioRepositoryProvider = Provider<InventarioRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return InventarioRepository(apiClient: api);
});

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return AdminRepository(apiClient: api);
});

final notificacionesRepositoryProvider = Provider<NotificacionesRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return NotificacionesRepository(apiClient: api);
});
