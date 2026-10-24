import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/errors/app_exceptions.dart';
import '../models/usuario_model.dart';
import '../repositories/auth_repository.dart';
import 'storage_provider.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  requiresFirstLogin,
  unauthenticated,
  error,
}

class AuthState {
  final AuthStatus status;
  final UsuarioModel? user;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;
  bool get requiresFirstLogin => status == AuthStatus.requiresFirstLogin;

  AuthState copyWith({
    AuthStatus? status,
    UsuarioModel? user,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  final Ref _ref;

  AuthNotifier(this._authRepository, this._ref) : super(const AuthState()) {
    // Listen for remote session expirations
    _ref.listen(sessionExpiredTriggerProvider, (prev, next) {
      if (next > 0) {
        state = const AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Tu sesión ha expirado. Por favor ingresa nuevamente.',
        );
      }
    });
  }

  Future<void> checkAuthStatus() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final user = await _authRepository.obtenerPerfil();
      if (!user.primerLoginCompletado) {
        state = AuthState(
          status: AuthStatus.requiresFirstLogin,
          user: user,
        );
      } else {
        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
        );
      }
    } catch (_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login({
    required String identificador,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final user = await _authRepository.login(
        identificador: identificador,
        password: password,
      );

      if (!user.primerLoginCompletado) {
        state = AuthState(
          status: AuthStatus.requiresFirstLogin,
          user: user,
        );
      } else {
        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
        );
      }
    } on AppException catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> refreshProfile() async {
    try {
      final user = await _authRepository.obtenerPerfil();
      if (!user.primerLoginCompletado) {
        state = state.copyWith(
          status: AuthStatus.requiresFirstLogin,
          user: user,
        );
      } else {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
        );
      }
    } catch (_) {}
  }

  Future<void> completeFirstLogin() async {
    try {
      final user = await _authRepository.primerLoginFinalizar();
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
      );
    } catch (e) {
      throw AppException(message: 'No se pudo finalizar el primer login: $e');
    }
  }

  void actualizarUsuarioLocal(UsuarioModel usuario) {
    state = state.copyWith(user: usuario);
  }

  Future<void> logout() async {
    state = state.copyWith(status: AuthStatus.loading);
    await _authRepository.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthNotifier(repo, ref);
});

final currentUserProvider = Provider<UsuarioModel?>((ref) {
  return ref.watch(authNotifierProvider).user;
});
