import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logger/app_logger.dart';

/// 스토어를 연다. 열었으면 true. 테스트는 실제 스토어 대신 가짜를 넣는다.
typedef StoreLauncher = Future<bool> Function(Uri url);

/// 스토어 앱으로 보낸다 (#279). 실패는 false 로 돌려주고 흔적을 남긴다 —
/// 화면에 알리는 것은 부른 쪽 몫이다.
Future<bool> openStore(Uri url) async {
  try {
    return await launchUrl(url, mode: LaunchMode.externalApplication);
  } catch (e, st) {
    AppLogger.error('app-status', e, st, {
      'step': 'openStore',
      'scheme': url.scheme,
    });
    return false;
  }
}

final storeLauncherProvider = Provider<StoreLauncher>((ref) => openStore);
