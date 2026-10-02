import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';

import '../../features/onboarding/application/onboarding_notifier.dart'
    show localStorageProvider;
import '../logger/app_logger.dart';

/// 이룸이 화면에서 울리는 진동 네 가지 (이슈 #515).
///
/// 진동은 화면과 소리가 이미 알려준 것을 손으로 한 번 더 느끼게 하는 **보조 신호**다. 의미를
/// 새로 만들지 않는다. 소리·진동에 예민한 이룸이가 있어 기본은 약하고 짧다.
enum ChildHapticKind {
  /// 카드를 체크한 순간 — "톡".
  check(
    pattern: [0, 20],
    intensities: [0, 128],
    fallback: HapticFeedback.mediumImpact,
  ),

  /// 별 화면이 뜰 때 — "반짝". 약하게 두 번.
  star(
    pattern: [0, 15, 60, 15],
    intensities: [0, 80, 0, 80],
    fallback: HapticFeedback.lightImpact,
  ),

  /// 일과를 모두 끝냈을 때 — "축하". 점점 세지는 세 번, 강하게 끝난다. 하루에 한 번뿐인 순간이다.
  complete(
    pattern: [0, 15, 70, 25, 70, 40],
    intensities: [0, 60, 0, 140, 0, 255],
    fallback: HapticFeedback.heavyImpact,
  ),

  /// 체크를 해제했을 때 — "스윽". 가장 약하다.
  uncheck(
    pattern: [0, 10],
    intensities: [0, 50],
    fallback: HapticFeedback.selectionClick,
  );

  const ChildHapticKind({
    required this.pattern,
    required this.intensities,
    required this.fallback,
  });

  /// `[쉬는 ms, 울리는 ms, 쉬는 ms, 울리는 ms, …]` — 가장 긴 패턴도 약 0.3초 안에 끝난다.
  final List<int> pattern;

  /// [pattern] 과 같은 길이. 쉬는 자리는 0, 울리는 자리는 1~255 (세기).
  final List<int> intensities;

  /// 세기·패턴을 못 쓰는 휴대폰에서 대신 울리는 기본 진동.
  final Future<void> Function() fallback;
}

/// 실제로 진동을 울리는 쪽. 테스트에서 가짜로 바꿔 끼운다.
///
/// 플러그인(플랫폼 채널)을 위젯 테스트에서 타지 않으려는 경계다.
abstract interface class HapticDriver {
  Future<void> play(ChildHapticKind kind);
}

/// `vibration` 플러그인으로 패턴·세기를 울린다. 지원하지 않는 휴대폰은 기본 진동으로 갈음한다.
class VibrationHapticDriver implements HapticDriver {
  const VibrationHapticDriver();

  @override
  Future<void> play(ChildHapticKind kind) async {
    // 진동 하드웨어가 없으면(태블릿 등) 아무 일도 하지 않는다 — 실패가 아니다.
    if (await Vibration.hasVibrator() != true) return;
    if (await Vibration.hasCustomVibrationsSupport() == true) {
      await Vibration.vibrate(
        pattern: kind.pattern,
        intensities: kind.intensities,
      );
      return;
    }
    await kind.fallback();
  }
}

/// 이룸이 화면의 진동 창구. 스위치가 꺼져 있으면 울리지 않는다.
///
/// **진동 때문에 화면 흐름이 멈추면 안 된다.** 호출이 실패해도 삼키지 않고 로그로 남기되 밖으로
/// 던지지 않는다.
class ChildHaptics {
  ChildHaptics({required HapticDriver driver, required bool Function() isOn})
    : _driver = driver,
      _isOn = isOn;

  final HapticDriver _driver;
  final bool Function() _isOn;

  /// 기다리지 않아도 된다 — 진동이 끝나길 기다리느라 화면 전환이 늦어지면 안 된다.
  Future<void> play(ChildHapticKind kind) async {
    if (!_isOn()) return;
    try {
      await _driver.play(kind);
    } catch (e, st) {
      AppLogger.error('ChildHaptics.play(${kind.name})', e, st);
    }
  }
}

final hapticDriverProvider = Provider<HapticDriver>(
  (ref) => const VibrationHapticDriver(),
);

final childHapticsProvider = Provider<ChildHaptics>(
  (ref) => ChildHaptics(
    driver: ref.watch(hapticDriverProvider),
    // 켜짐/꺼짐은 눌릴 때마다 읽는다 — 설정에서 바꾼 값이 바로 반영된다.
    isOn: () => ref.read(childHapticOnProvider),
  ),
);

/// 진동 켜기/끄기. 보호자 설정과 이룸이 설정이 **같은 값 하나**를 본다 (한 휴대폰에 하나).
///
/// 저장된 적이 없거나 읽지 못하면 켜짐이다.
class ChildHapticOnNotifier extends Notifier<bool> {
  @override
  bool build() {
    try {
      return ref.read(localStorageProvider).isChildHapticOn;
    } catch (e, st) {
      AppLogger.error('ChildHapticOnNotifier.build', e, st);
      return true;
    }
  }

  /// 값을 바꾸고 저장한다. 켤 때는 [check] 진동을 한 번 울려 어떤 느낌인지 알려준다.
  Future<void> set(bool on) async {
    state = on;
    try {
      await ref.read(localStorageProvider).setChildHapticOn(on);
    } catch (e, st) {
      // 저장이 안 돼도 이번 실행 동안은 바뀐 값을 쓴다
      AppLogger.error('ChildHapticOnNotifier.set', e, st);
    }
    if (on) await ref.read(childHapticsProvider).play(ChildHapticKind.check);
  }
}

final childHapticOnProvider = NotifierProvider<ChildHapticOnNotifier, bool>(
  ChildHapticOnNotifier.new,
);
