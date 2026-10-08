import 'dart:io';
import 'dart:ui';

import 'package:package_info_plus/package_info_plus.dart';

import '../storage/local_storage.dart';

/// 첨부 기록 맨 위에 붙일 환경 정보. 읽지 못한 값은 '-' 로 두고 예외를 던지지 않는다.
///
/// [storage] 는 호출 시점에 읽는다 — 저장소를 올리지 않은 곳(일부 테스트)은 예외가 나도 '-' 다.
Future<String> buildAppLogHeader({LocalStorage Function()? storage}) async {
  String safe(String Function() read) {
    try {
      final v = read();
      return v.isEmpty ? '-' : v;
    } catch (_) {
      return '-';
    }
  }

  var app = '-';
  try {
    final info = await PackageInfo.fromPlatform();
    app = '${info.version}+${info.buildNumber}';
  } catch (_) {}

  final dispatcher = PlatformDispatcher.instance;
  return [
    '앱: $app',
    'OS: ${safe(() => '${Platform.operatingSystem} ${Platform.operatingSystemVersion}')}',
    '언어: ${safe(() => dispatcher.locale.toLanguageTag())}',
    '글자 크기 배율: ${safe(() => dispatcher.textScaleFactor.toStringAsFixed(2))}',
    '역할: ${safe(() => _roleLabel(storage!().selectedRole))}',
    '온보딩 완료: ${safe(() => storage!().isOnboardingCompleted ? '예' : '아니오')}',
    '화면 크기: ${safe(() => _screenSize(dispatcher))}',
  ].join('\n');
}

String _roleLabel(String? role) => switch (role) {
  'guardian' => '보호자',
  'elumi' => '이룸이',
  null => '-',
  final other => other,
};

/// 논리 픽셀 크기와 픽셀 비율.
String _screenSize(PlatformDispatcher dispatcher) {
  final view = dispatcher.views.first;
  final size = view.physicalSize / view.devicePixelRatio;
  return '${size.width.round()}x${size.height.round()} @${view.devicePixelRatio.toStringAsFixed(1)}x';
}
