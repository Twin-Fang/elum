import 'package:flutter/material.dart';

import '../../../../core/theme/theme_context_ext.dart';
import 'aurora_background.dart';

/// 일과 만들기 흐름 **전체가 함께 쓰는** 배경 (#380).
///
/// 전에는 화면마다 [AuroraBackground]를 따로 그렸다. 그러면 화면이 넘어갈 때
/// 새 화면이 **자기 배경째** 밀려 들어와, 색이 다른 보상 화면(분홍)에서는
/// 색 경계선이 화면을 가로질렀다. 원의 움직임도 화면마다 처음부터 다시 돌아
/// 넘어가는 순간 제자리로 튀었다.
///
/// 그래서 배경을 흐름 바깥(라우터의 ShellRoute)에 **하나만** 두고, 화면은 바탕을
/// 칠하지 않는다. 화면이 바뀌면 글자·버튼만 넘어가고, 배경은 그 자리에서
/// [tone]이 가리키는 색으로 번진다.
///
/// 화면은 [isPresent]로 이 배경 위에 있는지 보고, 없으면(단독 테스트·흐름 밖에서
/// 연 화면) 예전처럼 자기 배경을 그린다.
class RoutineFlowBackdrop extends StatelessWidget {
  const RoutineFlowBackdrop({
    super.key,
    required this.tone,
    required this.child,
  });

  /// 지금 맨 위 화면의 색. 라우터가 위치로 정한다 (`routineFlowToneOf`).
  final AuroraTone tone;

  /// 흐름의 Navigator.
  final Widget child;

  /// 이 배경 위에 있는가. true면 화면은 바탕을 투명하게 둔다.
  static bool isPresent(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_BackdropScope>() != null;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colors.background,
      child: Stack(
        children: [
          Positioned.fill(child: AuroraBackground(tone: tone)),
          Positioned.fill(child: _BackdropScope(child: child)),
        ],
      ),
    );
  }
}

class _BackdropScope extends InheritedWidget {
  const _BackdropScope({required super.child});

  @override
  bool updateShouldNotify(_BackdropScope oldWidget) => false;
}
