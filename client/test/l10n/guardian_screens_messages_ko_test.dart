import 'package:elum/core/l10n/current_l10n.dart';
import 'package:elum/core/l10n/l10n_context.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/features/guardian/presentation/reward_setup_screen.dart';
import 'package:elum/l10n/app_localizations_ko.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elum/features/guardian/application/routine_flow_state.dart';

/// 실패 안내만 표식으로 바꾼 가짜 번역 — 언어가 바뀐 상황을 만든다.
class _FakeL10n extends AppLocalizationsKo {
  @override
  String get failureHintOffline => 'OFFLINE-HINT';
}

void main() {
  final ko = lookupAppLocalizations(const Locale('ko'));

  // 비 ko 번역을 심은 테스트가 전역 통로를 남기지 않게 되돌린다
  tearDown(setAppL10nForTest);

  test('홈 인사말 — 줄바꿈 위치까지 시안 그대로', () {
    expect(ko.guardianHomeGreeting('하늘이'), '안녕하세요,\n하늘이 보호자님 👋🏻');
    // 받침 있는 이름·영문 이름도 같은 모양이다 (조사가 없는 문구)
    expect(ko.guardianHomeGreeting('민준'), '안녕하세요,\n민준 보호자님 👋🏻');
    expect(ko.guardianHomeGreeting('Sam'), '안녕하세요,\nSam 보호자님 👋🏻');
  });

  test('로딩 진행률 — 한 자리·두 자리·세 자리', () {
    expect(ko.routineLoadingPercent(5), '5% 진행됐어요');
    expect(ko.routineLoadingPercent(40), '40% 진행됐어요');
    expect(ko.routineLoadingPercent(100), '100% 진행됐어요');
  });

  test('보상 설명 정적 getter 는 읽을 때의 앱 언어를 따른다', () {
    final marked = _MarkedWhy();
    setAppL10nForTest(marked);
    expect(RewardSetupScreen.whyMessage, 'M-WHY');
  });

  test('추가 질문 칩 지우기 낭독 문구 — 값 2개', () {
    expect(ko.questionClearLabel('우산'), '우산 지우기');
    expect(ko.questionClearLabel('장화'), '장화 지우기');
  });

  group('로딩 실패의 네트워크 힌트는 문구가 아니라 원인을 상태에 둔다', () {
    test('원인만 담고 읽을 때 현재 언어로 푼다 — 언어가 바뀌면 같이 바뀐다', () {
      final state = const RoutineFlowState().copyWith(
        errorFault: NetworkFault.offline,
      );

      expect(state.errorFault, NetworkFault.offline);
      expect(state.errorHint, '인터넷 연결을 확인해주세요');

      // 같은 상태를 두고 앱 언어만 바뀐다 — 옛 언어로 남지 않는다
      setAppL10nForTest(_FakeL10n());
      expect(state.errorHint, 'OFFLINE-HINT');
    });

    test('원인이 없거나 힌트가 없는 원인이면 null 이다', () {
      expect(const RoutineFlowState().errorHint, isNull);
      expect(
        const RoutineFlowState()
            .copyWith(errorFault: NetworkFault.app)
            .errorHint,
        isNull,
      );
    });

    test('timeout·인증서 원인도 손으로 쓴 문구로 풀린다', () {
      expect(
        const RoutineFlowState()
            .copyWith(errorFault: NetworkFault.timeout)
            .errorHint,
        '연결이 느려요. 잠시 후 다시 해주세요',
      );
      expect(
        const RoutineFlowState()
            .copyWith(errorFault: NetworkFault.badCertificate)
            .errorHint,
        '안전하지 않은 연결이에요. 다른 망에서 해주세요',
      );
    });
  });
}

class _MarkedWhy extends AppLocalizationsKo {
  @override
  String get rewardWhyMessage => 'M-WHY';
}
