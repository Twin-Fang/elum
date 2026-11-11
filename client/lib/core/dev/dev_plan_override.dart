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

/// 결제 화면 강제 켜기 (빌드 설정 `ELUM_IAP_ENABLED`·서버 판매 스위치가 꺼진 테스트 빌드에서 Sandbox·라이선스 테스트용)
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

/// 크레딧 판매 화면 강제 켜기: 서버 `isSaleEnabled`·스토어 연결과 무관하게 내 크레딧의 꾸러미 구역을 보임
///
/// 스토어 값을 못 받으면 구역 자리에 값 오류(`E-CREDIT-PACK-PRICE`)가 보임. 메모리에만 둔다 (앱을 다시 켜면 꺼짐)
class DevCreditPackSaleForcedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// 릴리스 빌드(개발자 도구 꺼짐)에서는 켜지지 않는다
  void set(bool isForced) {
    state = AppConfig.showDevTools && isForced;
  }
}

final devCreditPackSaleForcedProvider =
    NotifierProvider<DevCreditPackSaleForcedNotifier, bool>(
      DevCreditPackSaleForcedNotifier.new,
    );

/// Pro 미리 보기 강제 켜기: 스토어 상품을 못 불러와도 `canPurchasePro` 를 참으로 (Pro 미리 보기 확인용)
///
/// `Pro로 보기` 로 요금제 화면까지 열려면 `결제 화면 켜기` 도 켠다 (상품이 없으면 가격 실패 화면).
/// 메모리에만 둔다 (앱을 다시 켜면 꺼짐)
class DevProTeaserForcedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// 릴리스 빌드(개발자 도구 꺼짐)에서는 켜지지 않는다
  void set(bool isForced) {
    state = AppConfig.showDevTools && isForced;
  }
}

final devProTeaserForcedProvider =
    NotifierProvider<DevProTeaserForcedNotifier, bool>(
      DevProTeaserForcedNotifier.new,
    );
