import 'package:dio/dio.dart';
import 'package:elum/core/l10n/l10n_context.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/features/auth/data/consent_document_repository.dart';
import 'package:elum/features/auth/data/consent_repository.dart';
import 'package:elum/features/auth/domain/app_role.dart';
import 'package:elum/features/auth/domain/consent_bundle.dart';
import 'package:elum/features/auth/domain/consent_documents.dart';
import 'package:elum/features/auth/presentation/consent_document_list_screen.dart';
import 'package:elum/features/auth/presentation/consent_document_screen.dart';
import 'package:elum/features/auth/presentation/consent_screen.dart';
import 'package:elum/features/auth/presentation/login_screen.dart';
import 'package:elum/features/auth/presentation/role_select_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/device_viewport.dart';
import '../helpers/pump_with_locale.dart';
import '../helpers/test_storage.dart';

/// 옮긴 auth 문구가 옛 한국어와 같다 — 값은 손으로 쓴 한국어로 고정한다.
void main() {
  useFigmaViewport();

  final ko = lookupAppLocalizations(const Locale('ko'));

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
            .platformDispatcher
            .accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });
  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  test('역할 카드 제목은 색이 다른 앞부분 + 나머지 — 합치면 옛 문구', () {
    expect(AppRole.guardian.roleWord, '보호자');
    expect(AppRole.elumi.roleWord, '이룸이');
    expect(AppRole.guardian.labelSuffix, '가 사용해요');
    expect(AppRole.guardian.label, '보호자가 사용해요');
    expect(AppRole.elumi.label, '이룸이가 사용해요');
    expect(AppRole.guardian.description, '일과를 만들고 관리해요');
    expect(AppRole.elumi.description, '일과를 실천해요');
    // 저장소로 가는 식별자는 번역하지 않는다
    expect(AppRole.guardian.storageValue, 'guardian');
    expect(AppRole.elumi.storageValue, 'elumi');
  });

  test('약관 칩·문서 줄의 필수/선택 표기 — 라벨을 골라 넘기는 방식', () {
    expect(ko.consentChipRequired('서비스 이용약관'), '[필수] 서비스 이용약관');
    expect(ko.consentChipOptional('마케팅 수신'), '[선택] 마케팅 수신');
    expect(ko.consentRequiredTag, '필수');
    expect(ko.consentOptionalTag, '선택');
    // 옛 코드: '${required ? '필수' : '선택'} · 버전 ${version}'
    expect(ko.consentDocumentMeta(ko.consentRequiredTag, '3'), '필수 · 버전 3');
    expect(ko.consentDocumentMeta(ko.consentOptionalTag, '10'), '선택 · 버전 10');
  });

  test('로그인 문구', () {
    expect(ko.loginKakaoButton, '카카오로 로그인');
    expect(ko.loginNaverButton, '네이버로 로그인');
    expect(ko.loginAppleButton, 'Apple로 로그인');
    expect(ko.loginConnecting, '연결하고 있어요');
    expect(ko.loginLastUsed, '최근 로그인');
    expect(ko.loginDuplicateTitle, '이미 가입된 계정이에요');
    expect(ko.loginDuplicateFallback, '처음 쓰신 방법으로 로그인해주세요');
    expect(ko.loginOfflineTitle, '인터넷 연결을 확인해주세요');
    expect(ko.loginOfflineFallback, '연결한 뒤 다시 해주세요');
    expect(ko.loginFailedTitle, '로그인하지 못했어요');
    expect(ko.loginFailedFallback, '잠시 후 다시 시도해주세요');
  });

  testWidgets('로그인 화면 — ko 문구를 ARB 에서 읽고, 비-ko 는 ko 로 떨어진다', (tester) async {
    LoginScreen.debugPretendIos = true;
    addTearDown(() => LoginScreen.debugPretendIos = null);
    for (final locale in const [Locale('ko'), Locale('ja')]) {
      await pumpWithLocale(
        tester,
        const LoginScreen(),
        locale: locale,
        wrap: (app) => ProviderScope(
          overrides: [testStorageOverride()],
          child: app,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('카카오로 로그인'), findsOneWidget);
      expect(find.text('네이버로 로그인'), findsOneWidget);
      expect(find.text('Apple로 로그인'), findsOneWidget);
    }
  });

  testWidgets('역할 선택 화면 — 제목·부제·버튼', (tester) async {
    for (final locale in const [Locale('ko'), Locale('ja')]) {
      await pumpWithLocale(
        tester,
        // canPop 을 읽으므로 라우터가 필요하다 — 돌아갈 곳 없는 한 화면짜리
        InheritedGoRouter(
          goRouter: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const RoleSelectScreen()),
            ],
          ),
          child: const RoleSelectScreen(),
        ),
        locale: locale,
        wrap: (app) => ProviderScope(
          overrides: [testStorageOverride()],
          child: app,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('이 휴대폰은 누가\n사용하나요?'), findsOneWidget);
      expect(find.text('보호자모드와 이룸이모드가 나눠져 있어요'), findsOneWidget);
      expect(find.text('다음'), findsOneWidget);
      expect(find.textContaining('가 사용해요', findRichText: true), findsNWidgets(2));
      expect(find.text('일과를 만들고 관리해요'), findsOneWidget);
      expect(find.text('일과를 실천해요'), findsOneWidget);
    }
  });

  testWidgets('약관 동의 화면 — 제목·부제·행 표시, 저장 실패는 기본 문구 + 코드', (tester) async {
    final repo = _FailingConsent(const AppFailure(fault: NetworkFault.none));
    await pumpWithLocale(
      tester,
      const ConsentScreen(),
      wrap: (app) => ProviderScope(
        overrides: [
          consentRepositoryProvider.overrideWithValue(repo),
          consentBundleProvider.overrideWith((ref) async => ConsentBundle.bundled),
        ],
        child: app,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('약관에 동의해주세요'), findsOneWidget);
    expect(find.text('서비스 사용을 위해 약관 동의가 필요해요'), findsOneWidget);
    expect(find.text('서비스 이용약관 전체 동의'), findsOneWidget);
    expect(find.text('필수'), findsWidgets);

    // 전체 동의 → 항목을 눌러 상세 내용을 볼 수 있어요
    await tester.tap(find.textContaining('전체 동의'));
    await tester.pumpAndSettle();
    expect(find.text('항목을 눌러 상세 내용을 볼 수 있어요'), findsOneWidget);

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('동의를 저장하지 못했어요. 다시 해주세요 (E-CONSENT)'), findsOneWidget);
  });

  testWidgets('약관 동의 저장 실패 — 오프라인이면 첫 문장 + 안내 + 코드', (tester) async {
    final repo = _FailingConsent(const AppFailure(fault: NetworkFault.offline));
    await pumpWithLocale(
      tester,
      const ConsentScreen(),
      wrap: (app) => ProviderScope(
        overrides: [
          consentRepositoryProvider.overrideWithValue(repo),
          consentBundleProvider.overrideWith((ref) async => ConsentBundle.bundled),
        ],
        child: app,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('전체 동의'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(
      find.text('동의를 저장하지 못했어요 · 인터넷 연결을 확인해주세요 (E-NET-OFFLINE)'),
      findsOneWidget,
    );
  });

  testWidgets('약관 목록 화면 — 제목·묶음 이름', (tester) async {
    await pumpWithLocale(
      tester,
      const ConsentDocumentListScreen(),
      wrap: (app) => ProviderScope(
        overrides: [
          consentBundleProvider.overrideWith((ref) async => ConsentBundle.bundled),
        ],
        child: app,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('약관 및 개인정보처리방침'), findsOneWidget);
    expect(find.text('필수항목'), findsOneWidget);
    expect(find.text('선택항목'), findsOneWidget);
  });

  testWidgets('약관 문서 화면 끝 줄 — 필수·선택 두 가지 모두 손으로 쓴 한국어와 같다', (tester) async {
    for (final required in [true, false]) {
      final item = consentItems.firstWhere((e) => e.required == required);
      await pumpWithLocale(tester, ConsentDocumentScreen(item: item));
      await tester.pumpAndSettle();
      final scroll = find.byType(Scrollable).first;
      final expected = '${required ? '필수' : '선택'} · 버전 ${item.version}';
      await tester.scrollUntilVisible(find.text(expected), 300, scrollable: scroll);
      expect(find.text(expected), findsOneWidget);
    }
  });
}

class _FailingConsent extends ConsentRepository {
  _FailingConsent(this.failure) : super(dio: Dio());

  final AppFailure failure;

  @override
  Future<AppFailure?> agree({
    required Set<String> agreedKeys,
    required String version,
  }) async => failure;
}
