import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub/core/system/platform_services.dart';
import 'package:moviehub/core/system/windows/windows_video_output_policy.dart';

void main() {
  test('通用平台默认启用 GPU 视频渲染', () {
    const policy = HardwareVideoOutputPolicy();

    expect(policy.enableHardwareAcceleration, isTrue);
  });

  test('Windows 使用兼容 HDMI 与多显卡的 CPU 视频渲染', () {
    const policy = WindowsVideoOutputPolicy();

    expect(policy.enableHardwareAcceleration, isFalse);
  });
}
