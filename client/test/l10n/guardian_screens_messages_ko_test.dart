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

  test('보상이 왜 필요한가요 — 정적 getter 도 같은 문구', () {
    expect(ko.rewardWhyTitle, '보상이 왜 필요한가요?');
    expect(
      RewardSetupScreen.whyMessage,
      '일과를 마친 뒤 기다리는 것이 있으면 이룸이가 끝까지 해낼 힘이 생겨요.\n'
      '한 달 뒤 선물보다 오늘 바로 줄 수 있는 작은 것이 더 잘 통해요.\n'
      '정하지 않아도 일과는 만들 수 있어요.',
    );
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

  test('비밀암호 설명은 키 하나를 세 곳이 쓴다', () {
    expect(ko.pinModeHint, '보호자모드로 변경할 때 사용하는 암호예요');
  });

  test('줄바꿈이 든 제목은 \\n 위치까지 같다', () {
    expect(ko.pinChangeVerifyTitle, '지금 비밀암호를\n입력해주세요');
    expect(ko.pinChangeCreateTitle, '보호자님만 아는\n비밀암호를 만들어주세요');
    expect(ko.pinChangeEnterTitle, '새 비밀암호를\n입력해주세요');
    expect(ko.pinChangeCreateConfirmTitle, '암호를 한번 더\n입력해주세요');
    expect(ko.pinChangeConfirmTitle, '비밀암호를 한번 더\n입력해주세요');
    expect(ko.rewardHeadlineTitle, '일과가 끝나면\n어떤 보상을 줄까요?');
    expect(ko.routineInputTitle, '오늘은 어떤 준비가\n필요한가요?');
    expect(
      ko.guardianSettingsWithdrawConfirmMessage,
      '만든 일과와 모은 별이 모두 사라져요\n다시 로그인해도 되돌릴 수 없어요',
    );
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
