import 'package:dio/dio.dart';
import 'package:elum/core/router/app_router.dart';
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

  testWidgets('일괄 동의를 다시 누르면 전부 꺼진다 (이슈 #235)', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tapItem(tester, allAgree()); // 전부 켬
    await tapItem(tester, allAgree()); // 전부 끔
    await tapItem(tester, cta());

    // 필수가 꺼졌으므로 진행되지 않는다
    expect(repo.calls, 0);
  });

  testWidgets('선택만 따로 끌 수 있다 (이슈 #235)', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tapItem(tester, allAgree());
    await tapChipMark(tester, optionalLabel); // 선택만 끈다
    await tapItem(tester, cta());

    // 전체 동의로 켜졌어도 개별로 되돌릴 수 있어야 한다.
    expect(repo.marketing, isFalse);
    expect(repo.calls, 1);
  });

  // 약관 다음은 이름이 아니라 **역할 선택**이다 (이슈 #212). 여기서 바로 이름을
  // 물으면 이룸이 휴대폰이 보호자 온보딩으로 빨려 들어간다.
  testWidgets('일괄 동의만으로 필수가 채워져 그대로 진행된다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tapItem(tester, allAgree());
    await tapItem(tester, cta());

    // 선택을 빼느라 필수까지 덜 켜지면 화면이 막힌다.
    expect(find.text('역할 선택'), findsOneWidget);
  });

  testWidgets('선택 항목만 눌러도 켜진다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tapChipMark(tester, optionalLabel);
    // 필수가 덜 찼으므로 전체 동의로 마저 채운다
    await tapItem(tester, allAgree());
    await tapItem(tester, cta());

    expect(repo.marketing, isTrue);
  });

  // 부제가 상태를 말한다 (이슈 #226). 고정 문구로 두면 `다음`이 왜 꺼져 있는지
  // 알 방법이 없다 — 비활성 버튼 앞에서 막힌 사람에게 유일한 단서다.
  testWidgets('필수가 덜 찼으면 부제가 동의가 필요하다고 말한다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('서비스 사용을 위해 약관 동의가 필요해요'), findsOneWidget);
    expect(find.text('항목을 눌러 상세 내용을 볼 수 있어요'), findsNothing);
  });

  testWidgets('필수를 다 채우면 부제가 상세 보기를 안내한다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tapItem(tester, allAgree());

    expect(find.text('항목을 눌러 상세 내용을 볼 수 있어요'), findsOneWidget);
    expect(find.text('서비스 사용을 위해 약관 동의가 필요해요'), findsNothing);
  });

  testWidgets('제목과 CTA가 디자인 문구다 (이슈 #226)', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('약관에 동의해주세요'), findsOneWidget);
    expect(find.text('다음'), findsOneWidget);
    // 디자인에 없다 — 빼기로 했다
    expect(find.text('다른 계정으로 로그인'), findsNothing);
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
  Future<bool> agree({
    required bool marketingAgreed,
    required String version,
  }) async {
    calls++;
    marketing = marketingAgreed;
    this.version = version;
    return true;
  }
}
