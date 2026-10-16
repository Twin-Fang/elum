@Tags(['golden'])
library;

import 'package:dio/dio.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_dialog.dart';
import 'package:elum/features/auth/data/consent_document_repository.dart';
import 'package:elum/features/auth/domain/consent_bundle.dart';
import 'package:elum/features/auth/presentation/consent_document_list_screen.dart';
import 'package:elum/features/credit/data/credit_repository.dart';
import 'package:elum/features/credit/domain/credit_summary.dart';
import 'package:elum/features/guardian/presentation/draft_routines_screen.dart';
import 'package:elum/features/auth/domain/consent_documents.dart';
import 'package:elum/features/auth/presentation/consent_document_screen.dart';
import 'package:elum/features/guardian/presentation/guardian_settings_screen.dart';
import 'package:elum/features/link/data/device_link_repository.dart';
import 'package:elum/features/link/domain/link_status.dart';
import 'package:elum/features/link/presentation/link_code_screen.dart';
import 'package:elum/features/member/application/member_providers.dart';
import 'package:elum/features/profile/data/profile_repository.dart';
import 'package:elum/features/profile/domain/guardian_member.dart';
import 'package:elum/features/profile/presentation/guardians_screen.dart';
import 'package:elum/features/profile/presentation/invite_code_screen.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/credit_fixtures.dart';
import 'helpers/device_viewport.dart';
import 'helpers/precache_images.dart';
import 'helpers/profile_fixtures.dart';
import 'helpers/test_storage.dart';
import 'package:elum/core/storage/in_memory_storage.dart';
import 'package:elum/features/guardian/application/routine_providers.dart';

/// 설정 묶음 화면의 **시안 대조용** 렌더 (#349).
///
/// 값만 맞추고 렌더를 맞대지 않으면 통째로 어긋난 것을 놓친다 — 실제로 설정 제목을
/// 네비게이션 제목(18/w600 Pretendard)이 아니라 페이지 제목(28/w800 Tmoney)으로
/// 만들어 두고 "맞췄다"고 판단했다.
Future<void> _pump(WidgetTester tester, Widget screen, {List<Object> extra = const []}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
        ...extra.cast(),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        useInheritedMediaQuery: true,
        builder: (context, _) => MaterialApp.router(
          theme: AppTheme.light,
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(padding: deviceInsets),
            child: child!,
          ),
          routerConfig: GoRouter(
            initialLocation: '/x',
            routes: [GoRoute(path: '/x', builder: (context, state) => screen)],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await precacheAllImages(tester);
  await tester.pump(const Duration(milliseconds: 200));
}

/// 기기 안전영역 — 시안이 그린 상태바(59)·홈인디케이터(21)를 재현한다.
const deviceInsets = EdgeInsets.only(top: 59, bottom: 21);

void main() {
  // 없으면 800×600 으로 찍혀 시안과 맞댈 수 없다.
  useFigmaViewport();

  // 설정 메인 시안 `1532:7501` (#683): 크레딧 카드 + 흰 묶음 카드 넷. 시안 자리 그대로다.
  //
  // **알려진 차이**
  // - `문의하기` 줄은 일부러 뺐다 (#312, 시안에도 없다).
  // - 앱 정보 오른쪽 값: 시안은 자리 표시 글자 `버전 정보`, 앱은 실제 버전이다. 시험 환경은 버전을 못 읽어 비어 있다.
  // - `이룸이 바꾸기` 줄은 이룸이가 둘 이상일 때만 보이며 시안에 없다. 이 렌더에는 없다.
  // - 크레딧 카드는 시안 값(남은 90 / 100, 10월 19일(월) 0시)으로 찍는다.
  // - 시안 프레임은 852 에서 잘려 계정 묶음이 보이지 않는다 (스크롤 아래). 같은 크기로 찍으므로 같은 모양이다.
  testWidgets('설정 (Figma 1532:7501)', (tester) async {
    await _pump(
      tester,
      const GuardianSettingsScreen(),
      extra: [
        creditSummaryProvider.overrideWith(
          (ref) async => CreditSummary.fromJson({
            ...creditJson(available: 90),
            'nextResetAt': '2026-10-19T00:00:00',
          }),
        ),
      ],
    );
    await expectLater(
      find.byType(GuardianSettingsScreen),
      matchesGoldenFile('figma/settings_1532-7501.png'),
    );
  });

  // 시안 1045:4910 은 이제 줄이 둘 그려져 있다(#496). 첫 줄은 보상이 있고 둘째 줄은 `미설정`이다.
  final draftRoutines = [
    const Routine(
      id: 'd1',
      title: '스스로 옷을 입어요',
      status: 'PENDING_REVIEW',
      rewardText: '유튜브 시청 20분',
    ),
    const Routine(
      id: 'd2',
      title: '스스로 옷을 입어요',
      status: 'PENDING_REVIEW',
    ),
  ];

  testWidgets('설정 — 임시저장 (Figma 1045:4910)', (tester) async {
    await _pump(
      tester,
      const DraftRoutinesScreen(),
      extra: [myRoutinesProvider.overrideWith((ref) async => draftRoutines)],
    );
    await expectLater(
      find.byType(DraftRoutinesScreen),
      matchesGoldenFile('figma/settings_drafts_1045-4910.png'),
    );
  });

  // 둘째 줄을 왼쪽으로 밀어 삭제 버튼이 나온 모습 (Figma 1274:9262, #496).
  testWidgets('설정 — 임시저장 밀어서 삭제 (Figma 1274:9262)', (tester) async {
    await _pump(
      tester,
      const DraftRoutinesScreen(),
      extra: [myRoutinesProvider.overrideWith((ref) async => draftRoutines)],
    );
    // 시안은 줄이 75 비켜난 모습이다
    await tester.drag(find.text('미설정'), const Offset(-80, 0));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(DraftRoutinesScreen),
      matchesGoldenFile('figma/settings_drafts_delete_1274-9262.png'),
    );
  });

  testWidgets('설정 — 약관 목록 (Figma 1027:4683)', (tester) async {
    await _pump(
      tester,
      const ConsentDocumentListScreen(),
      extra: [
        consentBundleProvider.overrideWith((ref) async => ConsentBundle.bundled),
      ],
    );
    await expectLater(
      find.byType(ConsentDocumentListScreen),
      matchesGoldenFile('figma/settings_terms_1027-4683.png'),
    );
  });

  testWidgets('설정 — 이룸이 휴대폰 연결 (Figma 1532:6671)', (tester) async {
    // 설정에서 들어온 화면이다: `fromOnboarding: false`.
    // 온보딩 시안(`732:5334`)과 머리·하단이 다르므로 둘을 같은 골든으로 묶으면
    // 한쪽이 어긋나도 드러나지 않는다.
    await _pump(
      tester,
      const LinkCodeScreen(),
      extra: [deviceLinkRepositoryProvider.overrideWithValue(_FakeLink())],
    );
    await expectLater(
      find.byType(LinkCodeScreen),
      matchesGoldenFile('figma/settings_link_1532-6671.png'),
    );
  });

  // 시안 1579:8206 은 1532:6671 과 같은 모양이다 (제목·설명만 다르다).
  //
  // **알려진 차이**
  // - 시안의 이룸이 이름은 `하늘이`, 앱은 회원 정보의 호칭을 쓴다. 시험은 `하늘이`로 맞춘다.
  testWidgets('설정 — 다른 보호자 초대 (Figma 1579:8206)', (tester) async {
    await _pump(
      tester,
      const InviteCodeScreen(),
      extra: [
        profileRepositoryProvider.overrideWithValue(
          FakeProfileRepository()
            ..issueResult = Attempt.ok(
              IssuedLinkCode.fromNow(code: '5NJ280', expiresInSeconds: 599),
            ),
        ),
        memberProvider.overrideWith((ref) async => memberWith([kProfileA])),
      ],
    );
    await expectLater(
      find.byType(InviteCodeScreen),
      matchesGoldenFile('figma/settings_invite_1579-8206.png'),
    );
  });

  // 함께하는 사람 세 프레임 (Figma 1027:4617 · 1532:6877 · 1532:7013). 시안이 그린 세 사람 그대로 채운다.
  //
  // **알려진 차이 — 시트 프레임의 `이름없음`.** 시안 1532:6877·7013 은 스크림 뒤 내 줄 이름이
  // `이름없음`(검정 30%)인데 목록 시안 1027:4617 은 `보호자`다. 목록 시안을 따르므로 시트 두 프레임의
  // 그 글자만 붉게 남는다.
  final people = [
    const Guardian(id: 'g-1', me: true),
    const Guardian(id: 'g-2', me: false, displayName: '다른보호자이름'),
    const Guardian(
      id: 'g-3',
      me: false,
      displayName: '다른보호자이름',
      kind: GuardianKind.caregiver,
    ),
  ];

  Future<void> pumpPeople(WidgetTester tester) async {
    final repo = FakeProfileRepository()..guardiansResult = Attempt.ok(people);
    await _pump(
      tester,
      const GuardiansScreen(),
      extra: [
        profileRepositoryProvider.overrideWithValue(repo),
        memberProvider.overrideWith((ref) async => memberWith([kProfileA])),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('설정 — 함께하는 사람 (Figma 1027:4617)', (tester) async {
    await pumpPeople(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('figma/people_1027-4617.png'),
    );
  });

  testWidgets('설정 — 함께하는 사람 이름 변경, 비어 있음 (Figma 1532:6877)', (tester) async {
    await pumpPeople(tester);
    await tester.tap(find.text('이름 변경'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('figma/people_sheet_1532-6877.png'),
    );
  });

  testWidgets('설정 — 함께하는 사람 이름 변경, 선생님 (Figma 1532:7013)', (tester) async {
    await pumpPeople(tester);
    await tester.tap(find.text('이름 변경'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '2반 선생님');
    // 시트 안 구분 칩 (뒷 화면의 목록 칩과 겹치지 않게 시트 안에서 찾는다)
    await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text('선생님')));
    // 시안은 입력칸이 포커스를 받지 않은 모습
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('figma/people_sheet_teacher_1532-7013.png'),
    );
  });

  testWidgets('설정 — 약관 상세 (Figma 1027:4831)', (tester) async {
    final overseas = consentItems.firstWhere((e) => e.key == 'overseasTransferAgreed');
    await _pump(tester, ConsentDocumentScreen(item: overseas));
    await expectLater(
      find.byType(ConsentDocumentScreen),
      matchesGoldenFile('figma/settings_terms_detail_1027-4831.png'),
    );
  });

  // 로그아웃·회원탈퇴 팝업 (Figma `팝업` 1045:5194 `로그아웃/회원탈퇴`).
  //
  // 전에는 바텀시트로 따로 그려 두고 있었다 — 같은 확인을 앱이 두 모양으로
  // 했다 (#353).
  for (final (name, title, message, icon, tone) in [
    ('logout', '로그아웃 하실건가요?', null, ElumDialogIcon.alert,
        ElumDialogTone.danger),
    (
      'withdraw',
      '회원탈퇴 하실건가요?',
      '만든 일과와 모은 별이 모두 사라져요\n다시 로그인해도 되돌릴 수 없어요',
      ElumDialogIcon.alert,
      ElumDialogTone.danger,
    ),
  ]) {
    testWidgets('설정 — $name 팝업 (Figma 1045:5194)', (tester) async {
      await _pump(
        tester,
        Builder(
          builder: (context) => ElumDialogCard<bool>(
            title: title,
            message: message,
            icon: icon,
            actions: [
              const ElumDialogAction(
                label: '취소',
                value: false,
                tone: ElumDialogTone.neutral,
              ),
              ElumDialogAction(label: '확인', value: true, tone: tone),
            ],
          ),
        ),
      );
      await expectLater(
        find.byType(ElumDialogCard<bool>),
        matchesGoldenFile('figma/popup_${name}_1045-5194.png'),
      );
    });
  }

  // 실패 팝업 (Figma `팝업` 1045:5079 `로그인실패`). 앱의 실패는 전부 이 모양이다 (#433).
  //
  // **알려진 차이 — 식별자 줄.** 시안에는 없지만 제보 단서라 문장 아래에 적는다
  // (docs 예외처리 규칙). 그만큼(8 + 14줄) 버튼이 아래로 내려간다.
  testWidgets('실패 팝업 (Figma 1045:5079)', (tester) async {
    await _pump(
      tester,
      const ElumDialogCard<void>(
        title: '로그인하지 못했어요.\n잠시 후 다시 시도해주세요',
        code: 'E-AUTH',
        icon: ElumDialogIcon.alert,
        actions: [ElumDialogAction(label: '확인', tone: ElumDialogTone.danger)],
      ),
    );
    await expectLater(
      find.byType(ElumDialogCard<void>),
      matchesGoldenFile('figma/popup_loginfail_1045-5079.png'),
    );
  });
}

/// 암호를 고정한다. 진짜 저장소를 쓰면 매번 다른 여섯 글자가 나와 골든이 흔들린다.
class _FakeLink extends DeviceLinkRepository {
  _FakeLink()
      : super(
          dio: Dio(),
          tokens: InMemoryTokenStore(),
          storage: InMemoryStorage(),
        );

  @override
  Future<Attempt<IssuedLinkCode>> issue() async => Attempt.ok(
    IssuedLinkCode.fromNow(code: '5NJ280', expiresInSeconds: 599),
  );

  @override
  Future<Attempt<LinkStatus>> statusResult() async =>
      Attempt.ok(const LinkStatus(devices: []));
}
