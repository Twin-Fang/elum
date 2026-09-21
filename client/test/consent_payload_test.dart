import 'package:dio/dio.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/app_pressable.dart';
import 'package:elum/features/auth/data/consent_document_repository.dart';
import 'package:elum/features/auth/data/consent_repository.dart';
import 'package:elum/features/auth/domain/consent_bundle.dart';
import 'package:elum/features/auth/domain/consent_documents.dart';
import 'package:elum/features/auth/presentation/consent_screen.dart';
import 'package:elum/features/auth/presentation/widgets/consent_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';

/// 서버로 나가는 동의 본문 (이슈 #278 QA).
///
/// **보낸 값이 곧 증빙이다.** 전에는 필수 넷을 `true` 로 고정해서 보냈고,
/// 관리자가 필수를 끄자 사용자가 켜지 않은 항목이 동의로 기록됐다. 여기서는 대역을
/// 쓰지 않고 실제 [ConsentRepository] 가 만든 요청 본문을 가로채 확인한다.
void main() {
  useFigmaViewport();

  late Map<String, dynamic>? sent;

  Dio capturingDio() => Dio()
    ..interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      sent = Map<String, dynamic>.from(o.data as Map);
      h.resolve(Response(requestOptions: o, statusCode: 200, data: <String, dynamic>{}));
    }));

  Widget wrap(ConsentBundle bundle) {
    final router = GoRouter(initialLocation: Routes.consent, routes: [
      GoRoute(path: Routes.consent, builder: (_, _) => const ConsentScreen()),
      GoRoute(path: Routes.roleSelect, builder: (_, _) => const Scaffold(body: Text('역할 선택'))),
      GoRoute(path: Routes.login, builder: (_, _) => const Scaffold(body: Text('로그인'))),
    ]);
    return ProviderScope(
      overrides: [
        consentRepositoryProvider.overrideWithValue(ConsentRepository(dio: capturingDio())),
        consentBundleProvider.overrideWith((ref) async => bundle),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (_, _) => MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
  }

  Future<void> tapCheck(WidgetTester tester, String label) async {
    final row = find.ancestor(of: find.text(label), matching: find.byType(ConsentRow)).first;
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: row, matching: find.byType(AppPressable)).first);
    await tester.pumpAndSettle();
  }

  setUp(() => sent = null);

  testWidgets('켠 항목만 true 로 보낸다 — 소식 받기를 켜지 않으면 false', (tester) async {
    await tester.pumpWidget(wrap(ConsentBundle.bundled));
    await tester.pumpAndSettle();

    for (final item in consentItems.where((i) => i.required)) {
      await tapCheck(tester, item.label);
    }
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    expect(sent, {
      'termsAgreed': true,
      'privacyAgreed': true,
      'overseasTransferAgreed': true,
      'guardianConfirmed': true,
      'marketingAgreed': false,
      'consentVersion': ConsentBundle.bundled.version,
    });
  });

  // 지금 서버는 필수 여부를 법이 정한 값으로 고정해 이런 응답을 내지 않는다.
  // 그래도 앱은 **받은 대로 정직하게** 보내야 한다 — 어긋나면 서버가 400 으로 막는다.
  testWidgets('서버가 선택이라고 한 항목을 켜지 않으면 false 로 보낸다 (거짓 동의를 만들지 않는다)',
      (tester) async {
    final items = consentItems
        .map((i) => i.key == 'privacyAgreed'
            ? ConsentItem(key: i.key, label: i.label, required: false, summary: i.summary, body: i.body)
            : i)
        .toList();
    await tester.pumpWidget(wrap(ConsentBundle(
      version: '2026-09-18', items: items, source: ConsentSource.server)));
    await tester.pumpAndSettle();

    for (final label in ['서비스 이용약관', '개인정보 국외 이전', '만 14세 이상입니다']) {
      await tapCheck(tester, label);
    }
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    expect(sent?['privacyAgreed'], isFalse, reason: '켜지 않은 항목이 동의로 기록되면 안 된다');
  });
}
