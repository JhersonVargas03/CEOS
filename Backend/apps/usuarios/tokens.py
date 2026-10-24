from rest_framework_simplejwt.tokens import RefreshToken

def generar_tokens_para_usuario(usuario):
    """Genera access y refresh token JWT incluyendo el session_version del usuario."""
    refresh = RefreshToken.for_user(usuario)
    refresh['session_version'] = usuario.session_version
    refresh['username'] = usuario.username
    refresh['activo'] = usuario.activo

    access = refresh.access_token
    access['session_version'] = usuario.session_version
    access['username'] = usuario.username
    access['activo'] = usuario.activo

    return {
        'access': str(access),
        'refresh': str(refresh),
    }
