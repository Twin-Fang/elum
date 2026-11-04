import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

/// 개발자 도구의 요금제 흉내: 서버 값 그대로 · Free 처럼 · Pro 처럼
enum DevPlanOverride {
  server('서버 값 그대로'),
  free('Free 처럼'),
  pro('Pro 처럼');

  const DevPlanOverride(this.label);

  final String label;
}

/// 요금제 흉내 값. **이 기기 화면만** 바뀐다 — 서버 권한·크레딧·결제는 그대로다.
///
/// 메모리에만 둔다 — 앱을 다시 켜면 서버 값으로 돌아가 흉내가 남은 줄 모르고 지나치지 않게.
class DevPlanOverrideNotifier extends Notifier<DevPlanOverride> {
  @override
  DevPlanOverride build() => DevPlanOverride.server;

  /// 릴리스 빌드(개발자 도구 꺼짐)에서는 어떤 경로로 불려도 무시한다
  void set(DevPlanOverride value) {
    state = AppConfig.showDevTools ? value : DevPlanOverride.server;
  }
}

final devPlanOverrideProvider =
    NotifierProvider<DevPlanOverrideNotifier, DevPlanOverride>(
      DevPlanOverrideNotifier.new,
    );

/// 결제 화면 강제 켜기 (`ELUM_IAP_ENABLED=false` 인 테스트 빌드에서 Sandbox·라이선스 테스트용)
///
/// 화면만 켠다 — 실제 결제는 스토어 테스트 계정·서버 설정(SUBSCRIPTION_*_ENABLED)이 있어야 끝난다.
/// 메모리에만 둔다 (앱을 다시 켜면 꺼짐).
class DevPlanStoreForcedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// 릴리스 빌드(개발자 도구 꺼짐)에서는 켜지지 않는다
  void set(bool isForced) {
    state = AppConfig.showDevTools && isForced;
  }
}

final devPlanStoreForcedProvider =
    NotifierProvider<DevPlanStoreForcedNotifier, bool>(
      DevPlanStoreForcedNotifier.new,
    );
