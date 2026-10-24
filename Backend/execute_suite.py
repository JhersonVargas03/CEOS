import run_tests

if __name__ == '__main__':
    result = run_tests.run_django_tests([
        'apps.usuarios.tests',
        'apps.notificaciones.tests',
        'apps.auditoria.tests',
        'apps.inventario.tests',
    ])
    print(f"=== RESULTADO SUITE TEST: {result} fallos ===")
