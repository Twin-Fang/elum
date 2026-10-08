import 'package:elum/core/router/app_destination.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/features/auth/domain/app_role.dart';
import 'package:elum/features/child/presentation/mode_switch_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:elum/core/router/routes.dart';
import 'package:elum/core/router/route_redirect.dart';

/// 화면 이동 규칙의 모든 상태 조합 검사. 상태 48가지 × 등록된 모든 경로를 기계적으로 돈다.
/// 새 경로는 라우터 설정에서 읽혀 자동으로 검사된다. 생길 수 없는 조합도 돈다 — 저장값이 어긋난 채 켜져도
/// 사용자가 갇히면 안 된다.
void main() {
  // 등록된 모든 경로 — 라우터 설정에서 읽는다
  final paths = <String>{};
  void collect(List<RouteBase> routes) {
    for (final r in routes) {
      if (r is GoRoute) paths.add(r.path);
      collect(r.routes);
    }
  }

  final router = createRouter();
  collect(router.configuration.routes);
  router.dispose();

  // 경로 + 모드 전환 방향 (`to` 쿼리)
  final targets = <(String, String?)>[
    for (final p in paths) (p, null),
    for (final t in ModeSwitchTarget.values) (Routes.modeSwitch, t.name),
  ];

  final states = [
    for (final hasSession in [false, true])
      for (final isElumiDevice in [false, true])
        for (final role in <AppRole?>[null, ...AppRole.values])
          for (final onboardingCompleted in [false, true])
            for (final resumeOnElumiScreen in [false, true])
              (
                hasSession: hasSession,
                isElumiDevice: isElumiDevice,
                role: role,
                onboardingCompleted: onboardingCompleted,
                resumeOnElumiScreen: resumeOnElumiScreen,
              ),
  ];

  test('경로가 비어 있지 않다 — 라우터 설정을 실제로 읽었다', () {
    expect(paths, contains(Routes.login));
    expect(paths.length, greaterThan(20));
    expect(states, hasLength(48));
  });

  for (final s in states) {
    final label =
        '세션 ${s.hasSession ? '있음' : '없음'} · '
        '${s.isElumiDevice ? '이룸이 휴대폰' : '보호자 휴대폰'} · '
        '역할 ${s.role?.name ?? '없음'} · '
        '온보딩 ${s.onboardingCompleted ? '완료' : '미완료'} · '
        '${s.resumeOnElumiScreen ? '이룸이 화면에서 꺼짐' : '보호자 화면에서 꺼짐'}';

    String? redirect(String path, [String? to]) => resolveRedirect(
      path,
      hasSession: s.hasSession,
      onboardingCompleted: s.onboardingCompleted,
      skipOnboarding: false,
      isElumiDevice: s.isElumiDevice,
      hasRole: s.role != null,
      modeSwitchTo: to,
    );

    group(label, () {
      test('보내는 곳은 등록된 화면이고, 한 번에 멈춘다 (튕김이 반복되지 않는다)', () {
        final problems = <String>[];
        for (final (path, to) in targets) {
          final first = redirect(path, to);
          if (first == null) continue;
          if (!paths.contains(first)) {
            problems.add('$path → $first (등록되지 않은 경로)');
            continue;
          }
          final second = redirect(first);
          if (second != null) problems.add('$path → $first → $second (다시 튕김)');
        }
        expect(problems, isEmpty, reason: problems.join('\n'));
      });

      test('이 상태의 홈은 가드에 막히지 않는다', () {
        final home = resolveDestination(
          hasSession: s.hasSession,
          onboardingCompleted: s.onboardingCompleted,
          isElumiDevice: s.isElumiDevice,
          selectedRole: s.role?.storageValue,
          resumeOnElumiScreen: s.resumeOnElumiScreen,
        );
        expect(paths, contains(home));
        expect(redirect(home), isNull, reason: '홈 $home 이 다른 곳으로 바뀐다');
      });

      test('연결 화면 아래에 깔아 두는 곳은 가드에 막히지 않는다', () {
        final base = linkEnterBackTarget(hasSession: s.hasSession);
        expect(
          redirect(base),
          isNull,
          reason: '깔아 둔 $base 가 가드에 걸려 바뀌면 뒤로가기가 같은 화면만 보여 준다',
        );
        expect(redirect(Routes.linkEnter), isNull, reason: '연결 화면 자체도 열려야 한다');
      });
    });
  }
}
