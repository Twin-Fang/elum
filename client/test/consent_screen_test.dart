import 'package:dio/dio.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/auth/data/consent_document_repository.dart';
import 'package:elum/features/auth/data/consent_repository.dart';
import 'package:elum/features/auth/domain/consent_bundle.dart';
import 'package:elum/features/auth/domain/consent_documents.dart';
import 'package:elum/core/widgets/app_pressable.dart';
import 'package:elum/features/auth/presentation/consent_screen.dart';
import 'package:elum/features/auth/presentation/widgets/consent_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'package:elum/core/router/routes.dart';

/// 약관 동의 화면 (이슈 #189).
///
/// 선택 동의(광고성 정보 수신)는 **사용자가 보고 고른 것만** 켜져야 한다.
/// 기기 높이에 따라 접히는 항목이라, 일괄 동의가 거기까지 켜면 사용자는
/// 무엇에 동의했는지 모른 채 동의하게 된다. 실제로 그렇게 서버에 기록됐다.
void main() {
  useFigmaViewport();

  late _FakeConsent repo;

  // `선택` 배지는 이제 라벨과 분리된 별도 Text다 (이슈 #226) — 라벨만 찾는다.
  final optionalLabel =
      consentItems.firstWhere((item) => !item.required).label;

  Widget wrap() {
    final router = GoRouter(
      initialLocation: Routes.consent,
      routes: [
        GoRoute(
          path: Routes.consent,
          builder: (context, state) => const ConsentScreen(),
        ),
        GoRoute(
          path: Routes.onboardingName,
          builder: (context, state) => const Scaffold(body: Text('이름 화면')),
        ),
        GoRoute(
          path: Routes.roleSelect,
          builder: (context, state) => const Scaffold(body: Text('역할 선택')),
        ),
        GoRoute(
          path: Routes.login,
          builder: (context, state) => const Scaffold(body: Text('로그인 화면')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        consentRepositoryProvider.overrideWithValue(repo),
        // 약관은 서버에서 온다 (이슈 #278). 여기서는 네트워크를 타지 않도록
        // 앱 번들 기본값을 그대로 꽂는다.
        consentBundleProvider.overrideWith((ref) async => ConsentBundle.bundled),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, child) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
  }

  setUp(() => repo = _FakeConsent());

  /// 목록이 길어 대상이 화면 밖에 있을 수 있다. 보이게 한 뒤 누른다.
  Future<void> tapItem(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Finder allAgree() => find.textContaining('전체 동의');

  /// 항목은 **본문을 누르면 약관 문서가 열리고, 왼쪽 체크만 눌러야 선택**된다.
  /// 라벨을 그대로 누르면 다른 화면으로 넘어가 버린다.
  Finder chipMark(String label) => find
      .ancestor(of: find.text(label), matching: find.byType(ConsentRow))
      .first;
  Finder cta() => find.text('다음');

  Future<void> tapChipMark(WidgetTester tester, String label) async {
    final chip = chipMark(label);
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    // 체크는 줄 안 첫 번째 AppPressable — 본문(문서 열기)보다 앞에 있다.
    await tester.tap(
      find.descendant(of: chip, matching: find.byType(AppPressable)).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('일괄 동의는 선택 항목까지 켠다 (이슈 #235)', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tapItem(tester, allAgree());
    await tapItem(tester, cta());

    // 버튼이 `전체 동의`다. 필수만 켜면 다 켜진 줄 알고 넘어간다.
    // (한때 필수만 켰다 — 이슈 #189. 이름과 동작이 어긋나 되돌렸다.)
    expect(repo.marketing, isTrue);
    expect(repo.calls, 1);
  });

  // 서버본을 못 받아 기본값을 보여줬다면 **그 버전**으로 기록돼야 한다 (이슈 #278).
  // 서버 최신 버전을 적으면 사용자가 보지 않은 문서에 동의한 것으로 남는다.
  testWidgets('화면에 보여준 약관의 버전을 보낸다 (이슈 #278)', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tapItem(tester, allAgree());
    await tapItem(tester, cta());

    expect(repo.version, ConsentBundle.bundled.version);
  });

  testWidgets('필수가 덜 찼으면 진행되지 않는다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tapChipMark(tester, optionalLabel);
    await tapItem(tester, cta());

    expect(repo.calls, 0);
    expect(find.text('이름 화면'), findsNothing);
  });
}

/// 서버에 나가지 않는 대역. 무엇이 전달됐는지만 붙잡는다.
class _FakeConsent extends ConsentRepository {
  _FakeConsent() : super(dio: Dio());

  int calls = 0;
  bool? marketing;
  String? version;

  @override
  Future<AppFailure?> agree({
    required Set<String> agreedKeys,
    required String version,
  }) async {
    calls++;
    marketing = agreedKeys.contains('marketingAgreed');
    this.version = version;
    return null;
  }
}
