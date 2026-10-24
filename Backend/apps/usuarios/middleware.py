from django.http import JsonResponse
from rest_framework import status
from rest_framework_simplejwt.authentication import JWTAuthentication

class SessionVersionMiddleware:
    """Middleware global para validar la vigencia de la sesión en cada solicitud."""
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        user = getattr(request, 'user', None)
        if not user or not user.is_authenticated:
            header = request.headers.get('Authorization') or request.META.get('HTTP_AUTHORIZATION')
            if header and header.startswith('Bearer '):
                try:
                    authenticator = JWTAuthentication()
                    validated_token = authenticator.get_validated_token(header.split(' ')[1])
                    user = authenticator.get_user(validated_token)
                    request.user = user
                    request.auth = validated_token
                except Exception:
                    pass

        if hasattr(request, 'user') and request.user.is_authenticated:
            auth = getattr(request, 'auth', None)
            token_session_version = None
            if isinstance(auth, dict):
                token_session_version = auth.get('session_version')
            elif hasattr(auth, 'get'):
                token_session_version = auth.get('session_version')

            if token_session_version is not None and token_session_version != request.user.session_version:
                return JsonResponse({
                    'detalle': 'La sesión ha finalizado. Por favor, inicie sesión nuevamente.'
                }, status=status.HTTP_401_UNAUTHORIZED)

        response = self.get_response(request)
        return response


class PrimerLoginBloqueoMiddleware:
    """Middleware que bloquea peticiones operativas si primer_login_completado == False."""
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        user = getattr(request, 'user', None)
        if not user or not user.is_authenticated:
            header = request.headers.get('Authorization') or request.META.get('HTTP_AUTHORIZATION')
            if header and header.startswith('Bearer '):
                try:
                    authenticator = JWTAuthentication()
                    validated_token = authenticator.get_validated_token(header.split(' ')[1])
                    user = authenticator.get_user(validated_token)
                    request.user = user
                except Exception:
                    pass

        if user and user.is_authenticated and not user.primer_login_completado:
            path = request.path
            rutas_permitidas = [
                '/api/auth/primer-login',
                '/api/auth/me',
                '/api/auth/login',
                '/api/telegram/webhook',
                '/api/telegram/procesar-updates'
            ]
            if not any(path.startswith(ruta) for ruta in rutas_permitidas):
                return JsonResponse({
                    'error': 'Acceso denegado. Debe completar el flujo obligatorio de primer inicio de sesión.',
                    'primer_login_completado': False
                }, status=status.HTTP_403_FORBIDDEN)

        return self.get_response(request)
