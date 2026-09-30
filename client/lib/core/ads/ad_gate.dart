import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 광고를 띄울 수 있는 환경인가.
///
/// 지금은 모바일이면 전원에게 켜진다(Free 기본). 나중에 `FREE_ADS_REMOVED`·
/// `PRO_ADS_REMOVED`를 이 한 곳에 연결한다. 호스트(macOS) 위젯 테스트는
/// 모바일이 아니라 자동으로 꺼져 SDK를 건드리지 않는다.
final adsEnabledProvider = Provider<bool>(
  (ref) => !kIsWeb && (Platform.isAndroid || Platform.isIOS),
);
