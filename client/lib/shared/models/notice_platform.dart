import 'package:flutter/foundation.dart';

/// 공지·알림을 받는 플랫폼. 값은 서버 `NoticePlatform` enum 과 같다.
enum NoticePlatform {
  ios('IOS'),
  android('ANDROID');

  const NoticePlatform(this.wire);

  final String wire;

  /// `dart:io` 의 Platform 대신 [defaultTargetPlatform] 으로 가린다 —
  /// 테스트에서 바꿔 볼 수 있어야 스토어별 공지가 섞이지 않는지 확인할 수 있다.
  static NoticePlatform get current =>
      defaultTargetPlatform == TargetPlatform.iOS ? ios : android;
}
