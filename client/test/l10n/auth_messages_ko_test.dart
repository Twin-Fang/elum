import 'package:dio/dio.dart';
import 'package:elum/core/l10n/l10n_context.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/features/auth/data/consent_document_repository.dart';
import 'package:elum/features/auth/data/consent_repository.dart';
import 'package:elum/features/auth/domain/app_role.dart';
import 'package:elum/features/auth/domain/consent_bundle.dart';
import 'package:elum/features/auth/domain/consent_documents.dart';
import 'package:elum/features/auth/presentation/consent_document_screen.dart';
import 'package:elum/features/auth/presentation/consent_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/device_viewport.dart';
import '../helpers/pump_with_locale.dart';

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
    // 저장소로 가는 식별자는 번역하지 않는다
    expect(AppRole.guardian.storageValue, 'guardian');
    expect(AppRole.elumi.storageValue, 'elumi');
  });

  test('약관 칩·문서 줄의 필수/선택 표기 — 라벨을 골라 넘기는 방식', () {
    expect(ko.consentChipRequired('서비스 이용약관'), '[필수] 서비스 이용약관');
    expect(ko.consentChipOptional('마케팅 수신'), '[선택] 마케팅 수신');
    // 옛 코드: '${required ? '필수' : '선택'} · 버전 ${version}'
    expect(ko.consentDocumentMeta(ko.consentRequiredTag, '3'), '필수 · 버전 3');
    expect(ko.consentDocumentMeta(ko.consentOptionalTag, '10'), '선택 · 버전 10');
  });

  testWidgets('약관 동의 화면 — 저장 실패는 기본 문구 + 코드', (tester) async {
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

    await tester.tap(find.textContaining('전체 동의'));
    await tester.pumpAndSettle();

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
