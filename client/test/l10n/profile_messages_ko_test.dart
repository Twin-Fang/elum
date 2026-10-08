import 'package:elum/core/l10n/batchim.dart';
import 'package:elum/core/l10n/current_l10n.dart';
import 'package:elum/core/l10n/l10n_context.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/network/server_error.dart';
import 'package:elum/core/network/server_error_code.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/profile/data/profile_repository.dart';
import 'package:elum/features/profile/domain/guardian_member.dart';
import 'package:elum/features/profile/domain/invite_link.dart';
import 'package:elum/features/profile/domain/profile_summary.dart';
import 'package:elum/features/profile/application/invite_sharer.dart';
import 'package:elum/features/profile/presentation/guardian_edit_sheet.dart';
import 'package:elum/features/profile/presentation/guardians_screen.dart';
import 'package:elum/features/profile/presentation/invite_code_screen.dart';
import 'package:elum/features/profile/presentation/invite_enter_screen.dart';
import 'package:elum/features/profile/presentation/profile_switch_screen.dart';
import 'package:elum/shared/utils/korean_particle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/device_viewport.dart';
import '../helpers/profile_fixtures.dart';
import '../helpers/pump_with_locale.dart';
import 'package:elum/features/member/application/member_providers.dart';

/// 옮긴 profile 문구가 옛 한국어와 같다 — 기대값은 손으로 쓴 한국어이거나 변경 전 코드(`KoreanParticle`)의 출력이다.
void main() {
  useFigmaViewport();

  final ko = lookupAppLocalizations(const Locale('ko'));

  test('초대 문구의 조사 — 받침이 있으면 을, 없으면 를 (변경 전 KoreanParticle 출력과 같다)', () {
    // 변경 전 코드: '$name${name.objectParticle} …'. 받침 있음·없음, ㄹ 받침, 영문, 빈 이름
    const names = ['민준', '루미', '별', '하늘이', 'Amy', ''];
    for (final n in names) {
      expect(ko.inviteCodeAsk(n, batchimOf(n)), '받은 분이 $n${n.objectParticle} 함께 돌봐요', reason: '"$n"');
      expect(ko.inviteJoined(n, batchimOf(n)), '$n${n.objectParticle} 함께 돌보게 됐어요', reason: '"$n"');
    }
    // 손으로 쓴 한국어
    expect(ko.inviteCodeAsk('민준', batchimOf('민준')), '받은 분이 민준을 함께 돌봐요');
    expect(ko.inviteCodeAsk('루미', batchimOf('루미')), '받은 분이 루미를 함께 돌봐요');
    expect(ko.inviteJoined('민준', batchimOf('민준')), '민준을 함께 돌보게 됐어요');
    expect(ko.inviteJoined('루미', batchimOf('루미')), '루미를 함께 돌보게 됐어요');
  });

  test('이름이 들어가는 문구 — 조사는 현재 동작 그대로 고정이다', () {
    // 함께하는 사람 머리 설명은 받침과 무관하게 `를` 이다(현행 문구를 그대로 둔다)
    expect(ko.guardiansCaption('하늘'), '하늘를 함께 돌보는 사람이에요');
    expect(ko.guardiansCaption('루미'), '루미를 함께 돌보는 사람이에요');
    expect(ko.guardiansLeft('하늘이'), '하늘이에서 나왔어요');
    expect(ko.guardiansLeft('바다'), '바다에서 나왔어요');
    expect(ko.profileSwitchSelected('하늘'), '하늘, 지금 보는 이룸이');
    expect(ko.profileSwitchSelected('바다'), '바다, 지금 보는 이룸이');
  });

  test('초대 공유 메시지는 옛 문구와 줄바꿈까지 같다 — 링크는 문구가 아니다', () {
    expect(
      ko.inviteShareMessage(10, 'https://example.test/i/ABC', 'ABC DEF'),
      '이룸이를 함께 돌봐요. 아래 링크를 누르면 이룸 앱에 초대 코드가 채워져요.\n'
      '초대 코드는 10분 동안만 쓸 수 있어요.\n'
      '\n'
      'https://example.test/i/ABC\n'
      '\n'
      '링크가 열리지 않으면 앱에서 직접 넣어주세요.\n'
      '초대 코드 ABC DEF',
    );
    expect(
      ko.inviteShareMessage(1, 'https://example.test/i/XYZ', 'XYZ 123'),
      '이룸이를 함께 돌봐요. 아래 링크를 누르면 이룸 앱에 초대 코드가 채워져요.\n'
      '초대 코드는 1분 동안만 쓸 수 있어요.\n'
      '\n'
      'https://example.test/i/XYZ\n'
      '\n'
      '링크가 열리지 않으면 앱에서 직접 넣어주세요.\n'
      '초대 코드 XYZ 123',
    );
  });

  test('InviteLink.shareMessage 는 부를 때마다 앱 문구를 읽고 링크·코드를 그대로 싣는다', () {
    final text = InviteLink.shareMessage('A7K3M9', validFor: const Duration(minutes: 10));
    expect(
      text,
      '이룸이를 함께 돌봐요. 아래 링크를 누르면 이룸 앱에 초대 코드가 채워져요.\n'
      '초대 코드는 10분 동안만 쓸 수 있어요.\n'
      '\n'
      '${InviteLink.shareUrl('A7K3M9')}\n'
      '\n'
      '링크가 열리지 않으면 앱에서 직접 넣어주세요.\n'
      '초대 코드 A7K 3M9',
    );
    // 599초는 5초까지 봐줘 10분이고, 20초는 1분으로 올린다
    expect(
      InviteLink.shareMessage('A7K3M9', validFor: const Duration(seconds: 599)),
      contains('초대 코드는 10분 동안만'),
    );
    expect(
      InviteLink.shareMessage('A7K3M9', validFor: const Duration(seconds: 20)),
      contains('초대 코드는 1분 동안만'),
    );
    // getter 가 굳지 않는다 — 통로가 바뀌면 다음 호출에 따라간다(기본으로 되돌린다)
    setAppL10nForTest(lookupAppLocalizations(const Locale('ko')));
    addTearDown(setAppL10nForTest);
    expect(
      InviteLink.shareMessage('A7K3M9', validFor: const Duration(minutes: 10)),
      text,
    );
  });

  test('이름이 비었을 때의 대체 호칭과 구분 라벨 — 서버로 가는 값은 그대로다', () {
    expect(const ProfileSummary(id: 'p').displayName, '이룸이');
    expect(const ProfileSummary(id: 'p', nickname: '  ').displayName, '이룸이');
    expect(const ProfileSummary(id: 'p', nickname: '하늘').displayName, '하늘');
    expect(GuardianKind.guardian.label, '보호자');
    expect(GuardianKind.caregiver.label, '센터 선생님');
    expect(const Guardian(id: 'g', me: false).label, '보호자');
    expect(const Guardian(id: 'g', me: false, displayName: '엄마').label, '엄마');
    // 직렬화 값은 번역하지 않는다
    expect(GuardianKind.guardian.apiValue, 'GUARDIAN');
    expect(GuardianKind.caregiver.apiValue, 'CAREGIVER');
    expect(GuardianKind.fromApiValue('CAREGIVER'), GuardianKind.caregiver);
    expect(GuardianKind.fromApiValue('모르는값'), GuardianKind.guardian);
  });

  test('파괴적 동작의 확인 문구는 원문과 같다', () {
    expect(ko.guardiansLeaveConfirmTitle, '함께 돌보기를 그만둘까요?');
    expect(
      ko.guardiansLeaveConfirmMessageLast,
      '함께하는 보호자가 없어요\n나가면 이룸이와 만든 일과, 모은 별이 모두 사라져요\n되돌릴 수 없어요',
    );
    expect(
      ko.guardiansLeaveConfirmMessageOthers,
      '내가 연결한 이룸이 휴대폰이 있다면 연결이 끊어져요\n남은 보호자가 새 연결 암호를 만들어야 다시 쓸 수 있어요\n내가 만든 일과는 사라져요\n이룸이와 다른 보호자의 일과·별은 그대로예요',
    );
    expect(ko.guardiansLeaveConfirmAction, '그만두기');
    expect(ko.guardiansLeaveAction, '함께 돌보기 그만두기');
    expect(ko.guardiansLeaveHintAlone, '혼자 돌보고 있어서 그만두면 이룸이와 일과, 별이 모두 사라져요');
    expect(ko.guardiansLeaveHintWithOthers, '내가 만든 일과만 사라지고, 다른 보호자의 일과는 그대로예요');
    expect(ko.inviteCodeRetryNote, '다시 만들면 이전 코드는 쓸 수 없어요');
  });

  group('초대 코드 넣기 — 실패 문구는 종류로 들고 있다가 그릴 때 푼다', () {
    late FakeProfileRepository repo;

    setUp(() => repo = FakeProfileRepository());

    Widget app(List<ProfileSummary> joined) {
      final router = GoRouter(
        initialLocation: Routes.inviteEnter,
        routes: [
          GoRoute(path: Routes.inviteEnter, builder: (_, _) => const InviteEnterScreen()),
          GoRoute(path: Routes.guardian, builder: (_, _) => const Scaffold(body: Text('보호자 홈'))),
        ],
      );
      return ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(repo),
          localStorageProvider.overrideWithValue(InMemoryStorage()),
          memberProvider.overrideWith((ref) async => memberWith(joined)),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (context, child) => MaterialApp.router(theme: AppTheme.light, routerConfig: router),
        ),
      );
    }

    Future<void> submit(WidgetTester tester, AppFailure failure) async {
      repo.redeemResult = Attempt.failed(failure);
      await tester.pumpWidget(app([kProfileB]));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'A7K3M9');
      await tester.pumpAndSettle();
    }

    // 서버가 문구를 못 줄 때(알 수 없는 코드·본문 없음)의 기본 문구 + 식별자 — 옛 코드의 describe 결과와 같다
    AppFailure bare(int status) => AppFailure(
      fault: NetworkFault.none,
      server: ServerError(code: ServerErrorCode.unknown, statusCode: status),
    );

    final cases = <String, (AppFailure, String)>{
      '없는 코드': (bare(404), '초대 코드가 맞지 않아요 (E-INV-404/404)'),
      '만료': (bare(410), '초대 코드가 만료됐어요. 새 코드를 받아주세요 (E-INV-410/410)'),
      '시도 한도': (bare(429), '잠시 뒤에 다시 해주세요 (E-INV-429/429)'),
      '이미 함께함': (bare(409), '이미 함께하고 있는 이룸이예요 (E-INV-409/409)'),
      '그 밖의 실패': (const AppFailure(fault: NetworkFault.none), '연결하지 못했어요. 다시 해주세요 (E-INV)'),
    };
    for (final entry in cases.entries) {
      testWidgets('${entry.key}: 기본 문구와 식별자가 옛 문구와 같다', (tester) async {
        await submit(tester, entry.value.$1);
        expect(find.text(entry.value.$2), findsOneWidget);
      });
    }

    testWidgets('서버 문구가 있으면 그것이 기본 문구를 이긴다', (tester) async {
      await submit(tester, serverFailure(404, ServerErrorCode.profileInviteNotFound, '서버가 준 문구'));
      expect(find.text('서버가 준 문구 (PROFILE_INVITE_NOT_FOUND)'), findsOneWidget);
    });

    testWidgets('오프라인: 옛 describe 결과와 같고 입력은 남는다', (tester) async {
      const failure = AppFailure(fault: NetworkFault.offline);
      await submit(tester, failure);
      expect(
        find.text(failure.describe('연결하지 못했어요. 인터넷을 확인해주세요', 'E-NET')),
        findsOneWidget,
      );
      expect(find.textContaining('E-NET-OFFLINE'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'A7K3M9');
    });

    testWidgets('모양이 틀린 코드: 서버에 보내지 않고 E-INV-FORM 을 보인다', (tester) async {
      await tester.pumpWidget(app([kProfileB]));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'A0K3M9');
      await tester.pumpAndSettle();
      expect(repo.sentCodes, isEmpty);
      expect(find.text('초대 코드가 맞지 않아요 (E-INV-FORM)'), findsOneWidget);
    });

    testWidgets('합류하면 이름 뒤 조사가 받침에 맞는다 (바다→를)', (tester) async {
      await tester.pumpWidget(app([kProfileB]));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'A7K3M9');
      await tester.pumpAndSettle();
      expect(find.text('바다를 함께 돌보게 됐어요'), findsOneWidget);
    });

    testWidgets('받침 있는 이름(민준→을)', (tester) async {
      repo.redeemResult = Attempt.ok(
        ProfileJoin(
          profile: const ProfileSummary(id: 'p-c', nickname: '민준'),
          removedProfileIds: const [],
        ),
      );
      await tester.pumpWidget(app([kProfileB]));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'A7K3M9');
      await tester.pumpAndSettle();
      expect(find.text('민준을 함께 돌보게 됐어요'), findsOneWidget);
    });
  });

  group('화면이 ARB 문구를 읽는다 (문구를 바꾸면 이 테스트가 깨진다)', () {
    Future<void> show(WidgetTester tester, Widget screen) async {
      final repo = FakeProfileRepository();
      await pumpWithLocale(
        tester,
        screen,
        wrap: (child) => ProviderScope(
          overrides: [
            profileRepositoryProvider.overrideWithValue(repo),
            inviteSharerProvider.overrideWithValue((_) async {}),
            localStorageProvider.overrideWithValue(InMemoryStorage(onboardingCompleted: true, pin: '1234')),
            memberProvider.overrideWith((ref) async => memberWith([kProfileA, kProfileB])),
          ],
          child: child,
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('함께하는 사람: 제목·머리 설명·줄·설명', (tester) async {
      await show(tester, const GuardiansScreen());
      expect(find.text('함께하는 사람'), findsOneWidget);
      expect(find.text('하늘이를 함께 돌보는 사람이에요'), findsOneWidget);
      expect(find.text('다른 보호자 초대하기'), findsOneWidget);
      expect(find.text('받은 초대 코드 넣기'), findsOneWidget);
      expect(find.text('함께 돌보기 그만두기'), findsOneWidget);
      expect(find.text('나'), findsOneWidget);
      expect(find.text('센터 선생님'), findsOneWidget);
    });

    testWidgets('초대 코드 만들기: 제목·머리·안내·버튼', (tester) async {
      await show(tester, const InviteCodeScreen());
      expect(find.text('초대 코드'), findsOneWidget);
      expect(find.text('함께할 보호자에게\n코드를 알려주세요'), findsOneWidget);
      expect(find.text('받은 분이 하늘이를 함께 돌봐요'), findsOneWidget);
      expect(find.text('초대 코드 다시 만들기'), findsOneWidget);
      expect(find.text('다시 만들면 이전 코드는 쓸 수 없어요'), findsOneWidget);
      expect(
        find.text('이룸이가 쓰는 휴대폰은 여기서 붙이지 않아요\n설정의 이룸이 휴대폰에서 연결해요'),
        findsOneWidget,
      );
      expect(find.text('링크로 보내기'), findsOneWidget);
    });

    testWidgets('초대 코드 넣기: 제목과 어디서 받는지 안내', (tester) async {
      await show(tester, const InviteEnterScreen());
      expect(find.text('초대 코드를\n넣어주세요'), findsOneWidget);
      expect(find.text('함께하는 보호자에게 받은 여섯 글자예요'), findsOneWidget);
      expect(find.text('함께하는 보호자 휴대폰에서'), findsOneWidget);
      expect(find.text('설정 → 함께하는 사람'), findsOneWidget);
      expect(find.text('초대 코드를 만들면 여섯 글자가 나와요'), findsOneWidget);
    });

    testWidgets('이룸이 바꾸기: 제목과 지금 보는 줄을 낭독기가 읽는 문장', (tester) async {
      await show(tester, const ProfileSwitchScreen());
      expect(find.text('이룸이 바꾸기'), findsOneWidget);
      expect(find.bySemanticsLabel('하늘이, 지금 보는 이룸이'), findsOneWidget);
    });

    testWidgets('내 이름 고치기 시트: 제목·설명·예시·구분·저장', (tester) async {
      await show(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showGuardianEditSheet(context, me: const Guardian(id: 'g', me: true)),
            child: const Text('열기'),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      expect(find.text('내 이름 고치기'), findsOneWidget);
      expect(find.text('이 이룸이를 함께 돌보는 사람에게 보이는 이름이에요. 실명이 아니어도 괜찮아요'), findsOneWidget);
      expect(find.text('엄마, 아빠, 센터 선생님'), findsOneWidget);
      expect(find.text('보호자'), findsOneWidget);
      expect(find.text('센터 선생님'), findsOneWidget);
      expect(find.text('저장'), findsOneWidget);
    });
  });

  testWidgets('비-ko 로케일은 번역 전이라 ko 문구로 떨어진다', (tester) async {
    final repo = FakeProfileRepository();
    await pumpWithLocale(
      tester,
      const InviteEnterScreen(),
      locale: const Locale('en'),
      wrap: (child) => ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(repo),
          localStorageProvider.overrideWithValue(InMemoryStorage()),
          memberProvider.overrideWith((ref) async => memberWith([kProfileB])),
        ],
        child: child,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('함께하는 보호자에게 받은 여섯 글자예요'), findsOneWidget);
    expect(find.text('설정 → 함께하는 사람'), findsOneWidget);
  });
}
