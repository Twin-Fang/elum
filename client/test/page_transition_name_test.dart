import 'package:elum/core/router/app_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// 전환 페이지가 경로를 이름으로 달아야 화면 이동 기록에 어느 화면인지 남는다.
class _Names extends NavigatorObserver {
  final names = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      names.add(route.settings.name);
}

void main() {
  testWidgets('slide·fade·flow 페이지는 경로를 이름으로 단다', (tester) async {
    final observer = _Names();
    final router = GoRouter(
      initialLocation: '/a',
      observers: [observer],
      routes: [
        GoRoute(
          path: '/a',
          pageBuilder: (c, s) => slidePage(s, const Scaffold(body: Text('a'))),
        ),
        GoRoute(
          path: '/b',
          pageBuilder: (c, s) => fadePage(s, const Scaffold(body: Text('b'))),
        ),
        GoRoute(
          path: '/c',
          pageBuilder: (c, s) => flowPage(s, const Scaffold(body: Text('c'))),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    router.go('/b');
    await tester.pumpAndSettle();
    router.go('/c');
    await tester.pumpAndSettle();

    expect(observer.names, containsAll(['/a', '/b', '/c']));
  });
}
