import os
import glob

def update_file(path):
    with open(path, 'r') as f:
        content = f.read()
    
    if 'class _FakeAuthService implements AuthService {' in content:
        if '@override\n  Future<bool> ensureSession() async => true;' not in content:
            # find where class _FakeAuthService ends, but simpler is just to insert after the first method
            # Let's just insert it after the class declaration
            content = content.replace(
                'class _FakeAuthService implements AuthService {',
                'class _FakeAuthService implements AuthService {\n  @override\n  Future<bool> ensureSession() async => true;\n'
            )
            with open(path, 'w') as f:
                f.write(content)
            print(f"Updated {path}")

for root, dirs, files in os.walk('test'):
    for file in files:
        if file.endswith('.dart'):
            update_file(os.path.join(root, file))

