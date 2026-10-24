from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework.exceptions import AuthenticationFailed

class CustomJWTAuthentication(JWTAuthentication):
    def authenticate(self, request):
        header = self.get_header(request)
        if header is None:
            return None

        raw_token = self.get_raw_token(header)
        if raw_token is None:
            return None

        validated_token = self.get_validated_token(raw_token)
        user = self.get_user(validated_token)

        # Validación de session_version (cierre remoto / deslogueo global)
        token_session_version = validated_token.get('session_version')
        if token_session_version is not None and token_session_version != user.session_version:
            raise AuthenticationFailed('La sesión ha sido cerrada remotamente o ha expirado.', code='session_invalidated')

        return user, validated_token
