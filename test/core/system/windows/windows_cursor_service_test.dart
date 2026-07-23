import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub/core/system/windows/windows_cursor_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('moviehub/cursor');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('Windows 光标服务把启用状态发送给 Runner', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });

    final service = WindowsCursorService();
    await service.setPixelStyleEnabled(true);
    await service.setPixelStyleEnabled(false);

    expect(calls, hasLength(2));
    expect(calls.first.method, 'setPixelStyleEnabled');
    expect(calls.first.arguments, isTrue);
    expect(calls.last.arguments, isFalse);
  });

  test('没有 Windows Runner 时保持空操作', () async {
    final service = WindowsCursorService();

    await expectLater(service.setPixelStyleEnabled(true), completes);
  });
}
