import 'package:dio/dio.dart';
import 'package:elum/core/l10n/l10n_context.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/network/server_error.dart';
import 'package:elum/core/network/server_error_code.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/features/link/data/device_link_repository.dart';
import 'package:elum/features/link/domain/link_status.dart';
import 'package:elum/features/link/presentation/link_code_screen.dart';
import 'package:elum/features/link/presentation/link_enter_screen.dart';
import 'package:elum/features/link/presentation/widgets/link_code_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/device_viewport.dart';
import '../helpers/pump_with_locale.dart';
import '../helpers/test_storage.dart';
import 'package:elum/core/storage/in_memory_storage.dart';

/// 옮긴 link 문구가 옛 한국어와 같다 — 기대값은 손으로 쓴 한국어(옛 코드가 만들던 값)다.
void main() {
  useFigmaViewport();

  final ko = lookupAppLocalizations(const Locale('ko'));

  test('이름이 들어가는 문구 — 조사는 고정(`의`)이라 받침과 무관하다', () {
    // 받침 있음(하늘이는 없음, 별은 있음)·없음 모두 `의` 그대로
    expect(ko.linkCodeAskTitle('하늘이'), '하늘이의 휴대폰을\n연결할까요?');
    expect(ko.linkCodeAskTitle('별'), '별의 휴대폰을\n연결할까요?');
    expect(ko.linkCodeEnterHint('하늘이'), '하늘이의 휴대폰에서 아래 코드를 입력하세요');
    expect(ko.linkCodeEnterHint('민준'), '민준의 휴대폰에서 아래 코드를 입력하세요');
    // 이름이 비면 화면이 공용 호칭으로 대신한다
    expect(ko.linkCodeAskTitle(ko.commonElumiName), '이룸이의 휴대폰을\n연결할까요?');
  });

  test('번호 문구는 int 로 받는다', () {
    expect(ko.linkDeviceNumbered(1), '이룸이 휴대폰 1');
    expect(ko.linkDeviceNumbered(2), '이룸이 휴대폰 2');
    expect(ko.linkDeviceNumbered(10), '이룸이 휴대폰 10');
  });

  test('코드 안내와 밑줄 친 길 — 밑줄 친 부분은 안내문 안에 있어야 한다', () {
    expect(ko.linkEnterGuide, '코드는 보호자 휴대폰의\n설정 → 이룸이 휴대폰 연결하기에 있어요');
    expect(ko.linkEnterGuidePath, '설정 → 이룸이 휴대폰 연결하기');
    expect(ko.linkEnterGuide, contains(ko.linkEnterGuidePath));
  });

  test('코드 입력 실패 문구', () {
    expect(ko.linkEnterWrongCode, '암호가 맞지 않아요');
    expect(ko.linkEnterExpired, '암호가 만료됐어요. 새 암호를 받아주세요');
    expect(ko.linkEnterOffline, '연결하지 못했어요. 인터넷을 확인해주세요');
    expect(ko.linkEnterFailed, '연결하지 못했어요. 다시 해주세요');
    expect(ko.commonRetryLater, '잠시 후 다시 해주세요');
    expect(ko.linkEnterLinkLost, '연결이 끊어졌어요\n보호자에게 새 연결 암호를 받아 입력해주세요');
  });

  test('이룸이 설정 팝업 문구 — 줄바꿈까지', () {
    expect(ko.elumiSettingsLogoutTitle, '로그아웃 하실건가요?');
    expect(
      ko.elumiSettingsLogoutMessage,
      '이 휴대폰의 연결이 끊어져요\n다시 쓰려면 보호자에게\n연결 암호를 받아야 해요',
    );
    expect(ko.elumiSettingsLogoutFailTitle, '로그아웃하지 못했어요');
    expect(ko.elumiSettingsWithdrawTitle, '회원탈퇴 하실건가요?');
    expect(
      ko.elumiSettingsWithdrawMessage,
      '이 휴대폰의 연결만 끊어져요\n일과와 별은 보호자 휴대폰에 남고\n다시 쓰려면 보호자에게\n연결 암호를 받아야 해요',
    );
    expect(
      ko.inviteRejectedOnElumiDevice,
      '이 휴대폰에서는 초대를 받을 수 없어요\n보호자 휴대폰에서 열어주세요',
    );
    expect(ko.elumiSettingsWithdrawFailTitle, '탈퇴하지 못했어요');
    expect(ko.elumiSettingsExitFailedFallback, '잠시 후 다시 시도해주세요');
  });

  test('연결 상태 문구', () {
    expect(ko.linkStatusRevokeConfirmTitle, '연결을 끊을까요?');
    expect(
      ko.linkStatusRevokeConfirmMessage,
      '이룸이 휴대폰에서 일과를 볼 수 없어요\n다시 연결하려면 새 암호를 만들면 돼요',
    );
    expect(ko.linkStatusRevokeHint, '끊으면 이룸이 휴대폰에서\n일과를 볼 수 없어요');
    expect(ko.linkStatusRevoked, '연결을 끊었어요');
    expect(ko.linkStatusAlreadyRevoked, '이미 끊겨 있어요');
    expect(ko.linkStatusEmpty, '연결된 휴대폰이 없어요');
    expect(ko.linkStatusConnected, '연결됨');
  });

  test('연결된 날 — LinkedDevice.sinceLabel 은 옛 월·일 조립과 같다', () {
    // 손으로 쓴 값: 한 자리/두 자리 월·일, 연말·연초, 윤년
    final cases = <DateTime, String>{
      DateTime(2026, 9, 18): '9월 18일부터',
      DateTime(2026, 1, 1): '1월 1일부터',
      DateTime(2026, 1, 5): '1월 5일부터',
      DateTime(2026, 9, 5, 9, 5): '9월 5일부터',
      DateTime(2026, 10, 1): '10월 1일부터',
      DateTime(2026, 11, 11): '11월 11일부터',
      DateTime(2026, 12, 31, 23, 59): '12월 31일부터',
      DateTime(2027, 1, 1): '1월 1일부터',
      DateTime(2028, 2, 29): '2월 29일부터',
    };
    cases.forEach((at, expected) {
      expect(
        LinkedDevice(linkId: 'l', linkedAt: at).sinceLabel,
        expected,
        reason: '$at',
      );
      // 옛 코드가 만들던 조립과도 같다
      expect(expected, '${at.month}월 ${at.day}일부터');
    });
    expect(const LinkedDevice(linkId: 'l2', linkedAt: null).sinceLabel, isNull);
  });

  testWidgets('다시 만들기 칩 — 비우면 시안 문구, 넘기면 넘긴 문구', (tester) async {
    await pumpWithLocale(
      tester,
      Scaffold(
        body: Column(
          children: [
            LinkRetryChip(onTap: () {}),
            LinkRetryChip(label: '초대 코드 다시 만들기', onTap: () {}),
          ],
        ),
      ),
    );
    expect(find.text('코드 다시 만들기'), findsOneWidget);
    expect(find.text('초대 코드 다시 만들기'), findsOneWidget);
  });

  testWidgets('번역 전 언어는 ko 문구로 대체된다', (tester) async {
    await pumpWithLocale(
      tester,
      Scaffold(body: LinkRetryChip(onTap: () {})),
      locale: const Locale('ja'),
    );
    expect(find.text('코드 다시 만들기'), findsOneWidget);
  });

  group('코드 입력 화면 — 글자가 ARB 에서 온다', () {
    late _EnterFake repo;
    setUp(() => repo = _EnterFake());

    Future<void> pumpEnter(WidgetTester tester) => pumpWithLocale(
      tester,
      const LinkEnterScreen(),
      wrap: (app) => ProviderScope(
        overrides: [deviceLinkRepositoryProvider.overrideWithValue(repo)],
        child: app,
      ),
    );

    Future<void> submit(WidgetTester tester, String code) async {
      await tester.enterText(find.byType(TextField), code);
      await tester.pumpAndSettle();
      await tester.tap(find.text('시작하기'));
      await tester.pumpAndSettle();
    }

    testWidgets('제목·안내·버튼·낭독 이름', (tester) async {
      await pumpEnter(tester);
      await tester.pumpAndSettle();

      expect(find.text('보호자에게서 받은 코드를\n입력해주세요'), findsOneWidget);
      expect(find.text('코드는 보호자 휴대폰의\n설정 → 이룸이 휴대폰 연결하기에 있어요'), findsOneWidget);
      expect(find.text('시작하기'), findsOneWidget);
      expect(find.bySemanticsLabel('연결 암호 넣기'), findsOneWidget);
    });

    testWidgets('연결이 밖에서 끊겨 돌아오면 안내 대신 끊김을 말한다', (tester) async {
      repo.lost = true;
      await pumpEnter(tester);
      await tester.pumpAndSettle();

      expect(find.textContaining('연결이 끊어졌어요'), findsOneWidget);
      expect(find.textContaining('보호자 휴대폰의'), findsNothing);
    });

    testWidgets('실패 종류별 문구 — 서버 문구가 없으면 기본 문구와 에러 코드', (tester) async {
      final cases = <RedeemOutcome, String>{
        RedeemOutcome.notFound: '암호가 맞지 않아요',
        RedeemOutcome.expired: '암호가 만료됐어요. 새 암호를 받아주세요',
        RedeemOutcome.tooManyAttempts: '잠시 후 다시 해주세요 (E-LINK-429)',
        RedeemOutcome.offline: '연결하지 못했어요. 인터넷을 확인해주세요 (E-NET)',
        RedeemOutcome.failed: '연결하지 못했어요. 다시 해주세요 (E-LINK)',
      };
      for (final entry in cases.entries) {
        repo.outcome = entry.key;
        await pumpEnter(tester);
        await tester.pumpAndSettle();
        await submit(tester, 'A7K3M9');
        expect(find.text(entry.value), findsOneWidget, reason: '${entry.key}');
      }
    });

    testWidgets('서버가 준 문구가 기본 문구를 이긴다', (tester) async {
      repo.outcome = RedeemOutcome.failed;
      repo.failure = const AppFailure(
        fault: NetworkFault.none,
        server: ServerError(code: ServerErrorCode.unknown, message: '서버가 준 말'),
      );
      await pumpEnter(tester);
      await tester.pumpAndSettle();
      await submit(tester, 'A7K3M9');

      expect(find.textContaining('서버가 준 말'), findsOneWidget);
      expect(find.textContaining('연결하지 못했어요'), findsNothing);
    });
  });

  group('연결 암호 화면 — 글자가 ARB 에서 온다', () {
    Future<void> pumpCode(
      WidgetTester tester, {
      String nickname = '',
      bool fromOnboarding = true,
      _CodeFake? repo,
    }) => pumpWithLocale(
      tester,
      LinkCodeScreen(fromOnboarding: fromOnboarding),
      wrap: (app) => ProviderScope(
        overrides: [
          deviceLinkRepositoryProvider.overrideWithValue(repo ?? _CodeFake()),
          testStorageOverride(nickname: nickname),
        ],
        child: app,
      ),
    );

    // 이름 값마다 새 화면으로 띄운다 (받침 없음·있음)
    for (final name in ['하늘이', '별']) {
      testWidgets('이름이 $name 이면 제목·설명에 그대로 들어간다', (tester) async {
        await pumpCode(tester, nickname: name);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('$name의 휴대폰을\n연결할까요?'), findsOneWidget);
        expect(find.text('$name의 휴대폰에서 아래 코드를 입력하세요'), findsOneWidget);
      });
    }

    testWidgets('이름이 비면 이룸이로 대신하고 온보딩 글자를 쓴다', (tester) async {
      await pumpCode(tester);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('이룸이의 휴대폰을\n연결할까요?'), findsOneWidget);
      expect(find.text('시작하기'), findsOneWidget);
      expect(find.text('나중에 할게요'), findsOneWidget);
      expect(find.text('코드 다시 만들기'), findsOneWidget);
    });

    testWidgets('설정에서 열면 제목이 있고 시작하기가 없다', (tester) async {
      await pumpCode(tester, fromOnboarding: false);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('이룸이 휴대폰 연결'), findsOneWidget);
      expect(find.text('시작하기'), findsNothing);
    });

    testWidgets('발급이 실패하면 설명 자리에 기본 문구와 에러 코드', (tester) async {
      await pumpCode(tester, repo: _CodeFake()..fail = true);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('암호를 만들지 못했어요. 다시 해주세요 (E-LINK-NEW)'), findsOneWidget);
    });
  });
}

class _EnterFake extends DeviceLinkRepository {
  _EnterFake()
    : super(
        dio: Dio(),
        tokens: InMemoryTokenStore(),
        storage: InMemoryStorage(),
      );

  RedeemOutcome outcome = RedeemOutcome.linked;
  AppFailure? failure;
  bool lost = false;

  @override
  bool get linkWasLost => lost;

  @override
  Future<RedeemResult> redeem(String code) async =>
      RedeemResult(outcome, failure: failure);
}

class _CodeFake extends DeviceLinkRepository {
  _CodeFake()
    : super(
        dio: Dio(),
        tokens: InMemoryTokenStore(),
        storage: InMemoryStorage(),
      );

  bool fail = false;

  @override
  Future<Attempt<IssuedLinkCode>> issue() async => fail
      ? const Attempt.failed(AppFailure(fault: NetworkFault.none))
      : Attempt.ok(
          IssuedLinkCode.fromNow(code: '5NJ280', expiresInSeconds: 600),
        );

  @override
  Future<Attempt<LinkStatus>> statusResult() async =>
      const Attempt.ok(LinkStatus(devices: []));
}
