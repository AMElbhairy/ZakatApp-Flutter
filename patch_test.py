with open('test/services/cloud_backup_controller_test.dart', 'r') as f:
    content = f.read()

content = content.replace("expect(ok, isTrue);", "print('ok: $ok, err: ${controllers.cloud.lastError}, status: ${controllers.cloud.statusMessage}');\n    expect(ok, isTrue);")

with open('test/services/cloud_backup_controller_test.dart', 'w') as f:
    f.write(content)
