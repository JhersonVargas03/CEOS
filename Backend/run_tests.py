import os
import sys
import django
from django.test.utils import get_runner
from django.conf import settings

def run_django_tests(test_labels=None):
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'apps'))
    
    django.setup()
    
    TestRunner = get_runner(settings)
    test_runner = TestRunner(verbosity=2, interactive=False)
    
    labels = test_labels or ['apps.usuarios.tests']
    failures = test_runner.run_tests(labels)
    return failures

if __name__ == '__main__':
    labels = sys.argv[1:] if len(sys.argv) > 1 else ['apps.usuarios.tests']
    failures = run_django_tests(labels)
    sys.exit(bool(failures))
