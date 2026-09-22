@Tags(['golden'])
library;

import 'package:dio/dio.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/auth/data/consent_document_repository.dart';
import 'package:elum/features/auth/domain/consent_bundle.dart';
import 'package:elum/features/auth/presentation/consent_document_list_screen.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/presentation/draft_routines_screen.dart';
import 'package:elum/features/auth/domain/consent_documents.dart';
import 'package:elum/features/auth/presentation/consent_document_screen.dart';
import 'package:elum/features/guardian/presentation/guardian_settings_screen.dart';
import 'package:elum/features/link/data/device_link_repository.dart';
import 'package:elum/features/link/domain/link_status.dart';
import 'package:elum/features/link/presentation/link_code_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/precache_images.dart';
import 'helpers/test_storage.dart';

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

  testWidgets('설정 (Figma 1022:4467)', (tester) async {
    await _pump(tester, const GuardianSettingsScreen());
    await expectLater(
      find.byType(GuardianSettingsScreen),
      matchesGoldenFile('figma/settings_1022-4467.png'),
    );
  });

  testWidgets('설정 — 임시저장 0건 (Figma 1045:4910)', (tester) async {
    await _pump(
      tester,
      const DraftRoutinesScreen(),
      extra: [myRoutinesProvider.overrideWith((ref) async => const [])],
    );
    await expectLater(
      find.byType(DraftRoutinesScreen),
      matchesGoldenFile('figma/settings_drafts_1045-4910.png'),
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

  testWidgets('설정 — 이룸이 휴대폰 연결 (Figma 1027:4617)', (tester) async {
    // 설정에서 들어온 화면이다 — `fromOnboarding: false`.
    // 온보딩 시안(`732:5334`)과 머리·하단이 다르므로 둘을 같은 골든으로 묶으면
    // 한쪽이 어긋나도 드러나지 않는다.
    await _pump(
      tester,
      const LinkCodeScreen(),
      extra: [deviceLinkRepositoryProvider.overrideWithValue(_FakeLink())],
    );
    await expectLater(
      find.byType(LinkCodeScreen),
      matchesGoldenFile('figma/settings_link_1027-4617.png'),
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
  Future<LinkStatus> status() async => const LinkStatus(devices: []);
}
