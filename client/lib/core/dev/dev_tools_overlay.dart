import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/guardian/application/routine_notifier.dart';
import '../../features/guardian/application/routine_providers.dart';
import '../../features/onboarding/application/onboarding_notifier.dart';
import '../config/app_config.dart';
import '../l10n/app_locales.dart';
import '../router/routes.dart';
import '../storage/local_storage.dart';
import 'dev_locale_override.dart';
import 'dev_log_buffer.dart';
import 'dev_log_file.dart';
import 'dev_state_dump.dart';
import 'dev_tools_visibility.dart';

part 'dev_tools_sheet.dart';
part 'dev_tools_actions.dart';
part 'dev_tools_inspect.dart';
part 'dev_tools_widgets.dart';

/// 개발자 도구 오버레이 — 드래그 가능한 플로팅 버튼 + 기능 패널.
///
/// 온보딩을 한 번 마치면 저장값 때문에 시작 화면이 보호자 홈으로 넘어가
/// 온보딩 화면을 다시 볼 수 없다. 실기기에는 콘솔도 없어 로그 확인도 불가능하다.
/// 이 오버레이가 두 문제를 앱 안에서 해결한다.
///
/// `app.dart`의 `MaterialApp.router` builder에서 한 번 감싸므로
/// **화면별 코드는 전혀 건드리지 않는다.**
///
/// ⚠️ 정식 출시 전 제거 대상.
/// `.env`의 `ELUM_SHOW_DEV_TOOLS=false`로 끄거나,
/// `core/dev/`를 통째로 지우고 `app.dart`의 builder 한 줄을 제거한다.
class DevToolsOverlay extends StatefulWidget {
  const DevToolsOverlay({super.key, required this.child, required this.onNavigate});

  final Widget child;

  /// 화면 이동. `context.go`를 쓰지 않는 이유는 이 위젯이
  /// `MaterialApp.router`의 `builder`에 놓여 **GoRouter보다 위**라
  /// `context`로 라우터를 찾지 못하기 때문이다(No GoRouter found in context).
  /// 라우터를 가진 `app.dart`가 이동 방법을 넘겨준다.
  final void Function(String route) onNavigate;

  @override
  State<DevToolsOverlay> createState() => _DevToolsOverlayState();
}

class _DevToolsOverlayState extends State<DevToolsOverlay> {
  /// 버튼 위치. null이면 첫 레이아웃에서 우하단으로 잡는다.
  Offset? _position;

  static const _buttonSize = 48.0;

  /// 화면 가장자리 최소 여백 — 버튼이 완전히 잘려 못 누르는 상황을 막는다
  static const _edgeMargin = 8.0;

  /// 패널이 열려 있는지.
  bool _panelOpen = false;

  @override
  Widget build(BuildContext context) {
    // 플래그가 꺼져 있으면 아무것도 얹지 않는다.
    // 위젯 트리에 추가되는 것이 없어 런타임 비용이 0이다.
    if (!AppConfig.showDevTools) return widget.child;

    // 숨기기를 누르면 이번 실행 동안 버튼이 사라진다.
    // 되살리려면 작업관리자에서 앱을 완전히 종료했다 켠다.
    return ValueListenableBuilder<bool>(
      valueListenable: DevToolsVisibility.hidden,
      builder: (context, hidden, _) =>
          hidden ? widget.child : _buildOverlay(context),
    );
  }

  Widget _buildOverlay(BuildContext context) {

    // LayoutBuilder를 Stack 바깥에 둔다 — Positioned는 Stack의 직계 자식이어야 한다.
    // LayoutBuilder를 사이에 끼우면 ParentData 타입이 어긋나 런타임에 터진다.
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxX = constraints.maxWidth - _buttonSize - _edgeMargin;
        final maxY = constraints.maxHeight - _buttonSize - _edgeMargin;

        // 첫 프레임 기본 위치: 우하단. 하단 CTA 버튼을 가리지 않도록 조금 띄운다.
        final pos = _position ?? Offset(maxX, maxY - 80);
        final clamped = Offset(
          pos.dx.clamp(_edgeMargin, maxX),
          pos.dy.clamp(_edgeMargin, maxY),
        );

        return Stack(
          children: [
            widget.child,
            Positioned(
              left: clamped.dx,
              top: clamped.dy,
              child: _DraggableButton(
                size: _buttonSize,
                onDrag: (delta) => setState(() {
                  // 드래그 중에도 화면 밖으로 나가지 않게 즉시 클램프한다
                  _position = Offset(
                    (clamped.dx + delta.dx).clamp(_edgeMargin, maxX),
                    (clamped.dy + delta.dy).clamp(_edgeMargin, maxY),
                  );
                }),
                onTap: () => setState(() => _panelOpen = true),
              ),
            ),
            // 패널도 같은 Stack에 그린다.
            //
            // showModalBottomSheet·Overlay를 쓰지 않는 이유: 이 위젯은
            // MaterialApp의 builder에 놓여 Navigator·Overlay보다 "위"에 있다.
            // 둘 다 상위에서 찾지 못해 런타임에 터진다.
            // 직접 그리면 조상에 의존하지 않아 어느 위치에 놓여도 동작한다.
            if (_panelOpen)
              Positioned.fill(
                // 패널이 자기 Overlay 를 갖는다. 이 위젯은 Navigator·Overlay 보다 위에
                // 있어서, 로그 글자(SelectableText)를 누르면 선택 손잡이를 그릴 Overlay 를 못 찾아
                // `Null check operator used on a null value` 가 났다.
                child: Overlay(
                  initialEntries: [
                    OverlayEntry(
                      builder: (_) => SizedBox.expand(
                        child: _DevToolsSheet(
                          onClose: () => setState(() => _panelOpen = false),
                          onNavigate: widget.onNavigate,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

}

/// 끌어서 옮길 수 있는 버튼.
///
/// 아동도 보는 화면이므로 눈에 띄지 않는 반투명 회색을 쓴다.
class _DraggableButton extends StatelessWidget {
  const _DraggableButton({
    required this.size,
    required this.onDrag,
    required this.onTap,
  });

  final double size;
  final ValueChanged<Offset> onDrag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 테스트 빌드에서는 모든 화면에 떠 있다. 이름이 없으면 실기기 접근성
    // 검사에서 화면마다 이름 없는 버튼이 하나씩 잡힌다.
    return Semantics(
      container: true,
      button: true,
      label: '개발자 도구 열기',
      child: GestureDetector(
        onTap: onTap,
        onPanUpdate: (details) => onDrag(details.delta),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.bug_report, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}
