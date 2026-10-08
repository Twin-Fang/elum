import 'package:elum/core/app_status/app_status_repository.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/core/widgets/elum_dialog.dart';
import 'package:elum/features/auth/data/consent_document_repository.dart';
import 'package:elum/features/auth/domain/app_role.dart';
import 'package:elum/features/auth/domain/consent_bundle.dart';
import 'package:elum/features/link/application/link_reset.dart';
import 'package:elum/features/link/data/device_link_repository.dart';
import 'package:elum/features/link/domain/link_status.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';
import 'helpers/real_router.dart';
import 'package:elum/core/storage/in_memory_storage.dart';
import 'package:elum/core/router/routes.dart';

/// 계정 상태가 바뀌는 모든 길에서 사용자가 갇히지 않는다 — 실제 앱 라우터로 확인한다.
///
/// 행마다: 도착 화면 → 뒤로가기 → 앱 재시작(같은 저장값으로 시작 화면부터). 남은 저장값도 본다.
void main() {
  useFigmaViewport();

  late InMemoryStorage storage;
  late InMemoryTokenStore tokens;

  // 서버 응답 — 모두 성공
  const routes = <String, Object?>{
    'POST /api/auth/logout': <String, Object?>{},
    'DELETE /api/member/me': <String, Object?>{},
    'DELETE /api/device-links/current': <String, Object?>{},
  };

  // 보호자 설정 화면이 읽는 것 — 서버를 타지 않는다
  final settingsOverrides = [
    consentBundleProvider.overrideWith((ref) async => ConsentBundle.bundled),
    appVersionProvider.overrideWith((ref) async => '9.9.9'),
    linkStatusProvider.overrideWith((ref) async => Attempt.ok(LinkStatus.empty)),
  ];

  Future<void> givenGuardian() async {
    storage = InMemoryStorage(onboardingCompleted: true);
    await storage.setSelectedRole(AppRole.guardian.storageValue);
    await storage.setNickname('하늘이');
    tokens = InMemoryTokenStore(accessToken: 'a', refreshToken: 'r');
  }

  Future<void> givenLinkedElumi() async {
    storage = InMemoryStorage(elumiDevice: true, onboardingCompleted: true);
    await storage.setSelectedRole(AppRole.elumi.storageValue);
    await storage.setNickname('하늘이');
    tokens = InMemoryTokenStore(accessToken: 'a', refreshToken: 'r');
  }

  Future<void> confirm(WidgetTester tester, String row) async {
    // 설정 목록 맨 아래 줄은 화면 밖일 수 있다
    await tester.ensureVisible(find.text(row));
    await tester.pumpAndSettle();
    await tester.tap(find.text(row));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(ElumDialogCard<bool>),
        matching: find.text('확인'),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 같은 저장값으로 앱을 처음부터 다시 띄운다.
  Future<String> restart(WidgetTester tester) async {
    final app = await pumpRealRouter(
      tester,
      storage: storage,
      tokens: tokens,
      start: Routes.splash,
    );
    return topOf(app.router);
  }

  void expectSignedOutClean() {
    expect(tokens.hasSession, isFalse);
    expect(storage.isElumiDevice, isFalse, reason: '남으면 다음 시작이 연결 화면으로 끌려간다');
    expect(storage.selectedRole, isNull);
    expect(storage.nickname, isNull);
  }

  group('스스로 나간다 → 로그인 화면, 앱을 다시 켜도 로그인 화면', () {
    for (final (who, settings, row, given) in [
      ('보호자', Routes.guardianSettings, '로그아웃', givenGuardian),
      ('보호자', Routes.guardianSettings, '회원탈퇴', givenGuardian),
      ('이룸이', Routes.childSettings, '로그아웃', givenLinkedElumi),
      ('이룸이', Routes.childSettings, '회원탈퇴', givenLinkedElumi),
    ]) {
      testWidgets('$who $row', (tester) async {
        await given();
        final app = await pumpRealRouter(
          tester,
          storage: storage,
          tokens: tokens,
          start: settings,
          routes: routes,
          overrides: settingsOverrides,
        );

        await confirm(tester, row);

        expect(topOf(app.router), Routes.login);
        expect(app.router.canPop(), isFalse, reason: '뒤로가기로 지운 계정의 화면에 돌아가면 안 된다');
        expectSignedOutClean();
        expect(await restart(tester), Routes.login);
      });
    }
  });

  group('세션이 끝난다', () {
    testWidgets('보호자 → 로그인 화면, 앱을 다시 켜도 로그인 화면', (tester) async {
      await givenGuardian();
      final app = await pumpRealRouter(
        tester,
        storage: storage,
        tokens: tokens,
        start: Routes.guardianSettings,
        overrides: settingsOverrides,
      );

      await tokens.clear(); // 토큰 갱신 실패 — AuthRepository 가 지운다
      await handleSessionExpired(router: app.router, container: app.container);
      await tester.pumpAndSettle();

      expect(topOf(app.router), Routes.login);
      expect(await restart(tester), Routes.login);
    });

    testWidgets('이룸이(보호자가 연결을 끊음) → 연결 화면에서 끊겼다고 말하고, 뒤로가기는 로그인', (tester) async {
      await givenLinkedElumi();
      final app = await pumpRealRouter(
        tester,
        storage: storage,
        tokens: tokens,
        start: Routes.childSettings,
        overrides: settingsOverrides,
      );

      await handleSessionExpired(router: app.router, container: app.container);
      await tester.pumpAndSettle();

      expect(topOf(app.router), Routes.linkEnter);
      expect(find.textContaining('연결이 끊어졌어요'), findsOneWidget);
      expect(storage.isElumiDevice, isTrue, reason: '같은 이룸이에게 다시 붙을 수 있어야 한다');

      await tapBack(tester);
      expect(topOf(app.router), Routes.login, reason: '같은 연결 화면이 다시 나오면 갇힌 것이다');
    });

    testWidgets('끊긴 이룸이 휴대폰을 다시 켠다 → 연결 화면, 뒤로가기는 로그인', (tester) async {
      await givenLinkedElumi();
      await tokens.clear();
      await storage.setElumiLinkLost(true);

      final app = await pumpRealRouter(
        tester,
        storage: storage,
        tokens: tokens,
        start: Routes.splash,
      );
      expect(topOf(app.router), Routes.linkEnter);

      await tapBack(tester);
      expect(topOf(app.router), Routes.login);
    });
  });

  group('돌아갈 화면 없이 열린 화면의 뒤로가기 → 지금 상태의 홈', () {
    for (final (who, settings, home, given) in [
      ('보호자', Routes.guardianSettings, Routes.guardian, givenGuardian),
      ('이룸이', Routes.childSettings, Routes.child, givenLinkedElumi),
    ]) {
      testWidgets('$who 설정 → $home', (tester) async {
        await given();
        final app = await pumpRealRouter(
          tester,
          storage: storage,
          tokens: tokens,
          start: settings,
          overrides: settingsOverrides,
        );
        expect(app.router.canPop(), isFalse, reason: '전제: go 로 열렸다');

        await tapBack(tester);
        expect(topOf(app.router), home);
      });
    }
  });

  group('연결 화면의 뒤로가기', () {
    testWidgets('아래에 아무것도 없고 세션도 없으면 로그인', (tester) async {
      await givenLinkedElumi();
      await tokens.clear();
      final app = await pumpRealRouter(
        tester,
        storage: storage,
        tokens: tokens,
        start: Routes.linkEnter,
      );
      expect(app.router.canPop(), isFalse, reason: '전제: 돌아갈 화면이 없다');

      await tapBack(tester);
      expect(topOf(app.router), Routes.login);
    });

    testWidgets('아래에 아무것도 없고 세션이 있으면(역할만 고르고 연결 전) 역할 선택', (tester) async {
      storage = InMemoryStorage();
      await storage.setSelectedRole(AppRole.elumi.storageValue);
      tokens = InMemoryTokenStore(accessToken: 'a', refreshToken: 'r');
      final app = await pumpRealRouter(
        tester,
        storage: storage,
        tokens: tokens,
        start: Routes.linkEnter,
      );

      await tapBack(tester);
      expect(topOf(app.router), Routes.roleSelect);
    });

    testWidgets('역할 선택에서 이룸이를 고르고 들어왔으면 역할 선택으로 돌아간다', (tester) async {
      storage = InMemoryStorage();
      tokens = InMemoryTokenStore(accessToken: 'a', refreshToken: 'r');
      final app = await pumpRealRouter(
        tester,
        storage: storage,
        tokens: tokens,
        start: Routes.roleSelect,
      );

      app.router.push(Routes.linkEnter);
      await tester.pumpAndSettle();
      await tapBack(tester);
      expect(topOf(app.router), Routes.roleSelect);
    });
  });
}
