import 'package:flutter/widgets.dart';

/// 앱 위젯 트리 통째로 다시 만들기 (개발자 도구: 서버 바꾸기, 흉내 적용 뒤 홈 다시 열기)
/// ProviderScope 가 새로 생겨 Dio·repository·메모리 캐시가 모두 처음부터 만들어짐
/// 프로세스는 그대로라 정적 값(AppConfig, 흉내 상태)과 저장소 인스턴스는 남음
class AppRestart extends StatefulWidget {
  const AppRestart({super.key, required this.builder});

  /// 다시 만들 때마다 부름. ProviderScope 를 여기서 새로 만들어야 provider 가 초기화됨
  final WidgetBuilder builder;

  /// [context] 위의 [AppRestart] 를 찾아 다시 만듦. 없으면 false
  static bool restart(BuildContext context) {
    final state = context.findAncestorStateOfType<_AppRestartState>();
    state?._restart();
    return state != null;
  }

  @override
  State<AppRestart> createState() => _AppRestartState();
}

class _AppRestartState extends State<AppRestart> {
  Key _generationKey = UniqueKey();

  void _restart() => setState(() => _generationKey = UniqueKey());

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _generationKey, child: Builder(builder: widget.builder));
}
