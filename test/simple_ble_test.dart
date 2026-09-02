import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_simple_ble/flutter_simple_ble.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('flutter_simple_ble');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('scan starts on listen and stops after timeout', () async {
    final List<String> methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          methods.add(call.method);
          return true;
        });

    await Ble.scan(timeout: Duration.zero).drain<void>();

    expect(methods, <String>['startScan', 'stopScan']);
  });
}
