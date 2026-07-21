import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/guardian/application/routine_notifier.dart';
import '../../features/guardian/data/routine_repository.dart';
import '../../features/onboarding/application/onboarding_notifier.dart';
import '../config/app_config.dart';
import '../router/app_router.dart';
import 'dev_log_buffer.dart';

/// 개발자 도구 오버레이 — 드래그 가능한 플로팅 버튼 + 기능 패널.
///
/// 온보딩을 한 번 마치면 저장값 때문에 시작 화면이 보호자 홈으로 넘어가
/// 온보딩 화면을 다시 볼 수 없다. 실기기에는 콘솔도 없어 로그 확인도 불가능하다.
/// 이 오버레이가 두 문제를 앱 안에서 해결한다.
///
/// `app.dart`의 `MaterialApp.router` builder에서 한 번 감싸므로
/// **화면별 코드는 전혀 건드리지 않는다.**
///
/// ⚠️ 정식 출시 전 제거 대상. (이슈 #13)
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
                child: _DevToolsSheet(
                  onClose: () => setState(() => _panelOpen = false),
                  onNavigate: widget.onNavigate,
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
    return GestureDetector(
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
    );
  }
}

/// 개발자 도구 시트 — Overlay에 직접 올라간다.
///
/// `showModalBottomSheet`를 쓰지 않으므로 Navigator가 필요 없다.
/// 하위 화면 전환도 라우팅 대신 내부 상태로 처리한다.
class _DevToolsSheet extends StatefulWidget {
  const _DevToolsSheet({required this.onClose, required this.onNavigate});

  final VoidCallback onClose;
  final void Function(String route) onNavigate;

  @override
  State<_DevToolsSheet> createState() => _DevToolsSheetState();
}

enum _DevView { menu, logs, status, navigate, confirmReset }

class _DevToolsSheetState extends State<_DevToolsSheet> {
  _DevView _view = _DevView.menu;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 시트 밖을 누르면 닫힌다
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onClose,
              child: Container(color: Colors.black.withValues(alpha: 0.4)),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _Handle(),
                    _header(),
                    Flexible(child: _body()),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final title = switch (_view) {
      _DevView.menu => '개발자 도구',
      _DevView.logs => '로그',
      _DevView.status => '현재 상태',
      _DevView.navigate => '화면 이동',
      _DevView.confirmReset => '회원을 삭제할까요?',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          // 하위 화면에서는 메뉴로 돌아가는 버튼을 준다
          if (_view != _DevView.menu)
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: () => setState(() => _view = _DevView.menu),
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _body() => switch (_view) {
        _DevView.menu => _DevMenu(
            onSelect: (v) => setState(() => _view = v),
          ),
        _DevView.logs => const _LogViewer(),
        _DevView.status => const _StatusView(),
        _DevView.navigate => _NavigateView(
            onClose: widget.onClose,
            onNavigate: widget.onNavigate,
          ),
        _DevView.confirmReset => _ConfirmResetView(
            onCancel: () => setState(() => _view = _DevView.menu),
            onDone: widget.onClose,
            onNavigate: widget.onNavigate,
          ),
      };
}

/// 기능 목록.
class _DevMenu extends StatefulWidget {
  const _DevMenu({required this.onSelect});

  final ValueChanged<_DevView> onSelect;

  @override
  State<_DevMenu> createState() => _DevMenuState();
}

class _DevMenuState extends State<_DevMenu> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: [
        ListTile(
          leading: const Icon(Icons.speed),
          title: const Text('온보딩 건너뛰기'),
          subtitle: const Text('devFlag 토글'),
          trailing: Switch(
            value: AppConfig.skipOnboarding,
            onChanged: (value) {
              setState(() => AppConfig.skipOnboarding = value);
            },
          ),
        ),
        _Tile(
          icon: Icons.person_remove_outlined,
          label: '회원삭제',
          subtitle: '계정과 저장값을 지우고 처음부터',
          onTap: () => widget.onSelect(_DevView.confirmReset),
        ),
        _Tile(
          icon: Icons.article_outlined,
          label: '로그 보기',
          subtitle: '최근 ${DevLogBuffer.maxLines}줄',
          onTap: () => widget.onSelect(_DevView.logs),
        ),
        _Tile(
          icon: Icons.info_outline,
          label: '현재 상태',
          subtitle: '저장값·설정값 확인',
          onTap: () => widget.onSelect(_DevView.status),
        ),
        _Tile(
          icon: Icons.navigation_outlined,
          label: '화면 이동',
          subtitle: '온보딩 단계·보호자 홈',
          onTap: () => widget.onSelect(_DevView.navigate),
        ),
      ],
    );
  }
}

/// 회원삭제 확인 — 실수로 눌러 계정이 날아가지 않도록 한 단계 둔다.
///
/// `showDialog`를 쓰지 않는다. 이 위젯도 Navigator보다 위에 있어
/// 다이얼로그를 띄울 수 없다. 시트 안에서 화면만 바꾼다.
class _ConfirmResetView extends ConsumerWidget {
  const _ConfirmResetView({
    required this.onCancel,
    required this.onDone,
    required this.onNavigate,
  });

  final VoidCallback onCancel;
  final VoidCallback onDone;
  final void Function(String route) onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '계정과 저장된 호칭·목표·캐릭터·PIN이\n모두 지워집니다.\n같은 이름을 넣어도 새로 시작합니다.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    // 서버 계정까지 지운다. 서버가 실패해도 로컬은 반드시 지워진다.
                    await ref.read(authRepositoryProvider).deleteAccount();
                    // 메모리 상태도 비운다 — 저장소만 지우면 화면이 이전 값을 들고 있다.
                    // routineFlow(방금 만든 일과)·myRoutines(서버 조회 캐시)를 함께 비우지
                    // 않으면 재가입 후 홈에 이전 계정 일과가 그대로 노출된다 (이슈 #91).
                    ref.read(routineFlowProvider.notifier).reset();
                    ref.invalidate(myRoutinesProvider);
                    ref.invalidate(onboardingProvider);
                    if (!context.mounted) return;
                    onDone();
                    onNavigate(Routes.splash);
                  },
                  child: const Text('회원삭제'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 최근 로그를 보여준다. 복사 버튼 포함.
class _LogViewer extends StatelessWidget {
  const _LogViewer();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: DevLogBuffer.asText()),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    const SnackBar(content: Text('로그를 복사했어요')),
                  );
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('복사'),
              ),
              TextButton.icon(
                onPressed: DevLogBuffer.clear,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('비우기'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Flexible(
          // 새 로그가 쌓이면 즉시 갱신한다
          child: ValueListenableBuilder<int>(
            valueListenable: DevLogBuffer.revision,
            builder: (context, _, _) {
              final lines = DevLogBuffer.lines;
              if (lines.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('아직 로그가 없어요'),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.all(12),
                itemCount: lines.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: SelectableText(
                    lines[i],
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 저장값·설정값을 보여준다.
class _StatusView extends ConsumerWidget {
  const _StatusView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.read(localStorageProvider);

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      children: [
        const Text('저장값', style: TextStyle(fontWeight: FontWeight.bold)),
        _Row('온보딩 완료', '${storage.isOnboardingCompleted}'),
        _Row('호칭', storage.nickname ?? '(없음)'),
        _Row('목표', storage.goals.isEmpty ? '(없음)' : storage.goals.join(', ')),
        _Row('캐릭터', storage.character ?? '(없음)'),
        // PIN은 평문 저장 중이라 값을 띄우지 않는다 — 어깨너머 노출 방지
        FutureBuilder<String?>(
          future: storage.getPin(),
          builder: (context, snap) => _Row(
            'PIN',
            (snap.data?.isNotEmpty ?? false) ? '설정됨' : '(없음)',
          ),
        ),
        const SizedBox(height: 16),
        const Text('설정값', style: TextStyle(fontWeight: FontWeight.bold)),
        _Row('API', AppConfig.apiBaseUrl),
        _Row('Mock 사용', '${AppConfig.useMock}'),
        _Row('네트워크 로그', '${AppConfig.enableNetworkLog}'),
        _Row('온보딩 건너뛰기', '${AppConfig.skipOnboarding}'),
        _Row('DLP 최소 지연', '${AppConfig.dlpMinDelay.inMilliseconds}ms'),
      ],
    );
  }
}

/// 화면 바로 이동.
class _NavigateView extends StatelessWidget {
  const _NavigateView({required this.onClose, required this.onNavigate});

  final VoidCallback onClose;
  final void Function(String route) onNavigate;

  static const _destinations = <(String, String)>[
    ('시작', Routes.splash),
    ('온보딩 · 이름', Routes.onboardingName),
    ('온보딩 · 목표', Routes.onboardingGoals),
    ('온보딩 · 캐릭터', Routes.onboardingCharacter),
    ('온보딩 · PIN', Routes.onboardingPin),
    ('보호자 홈', Routes.guardian),
    // 아이 모드는 PIN을 거쳐야 들어갈 수 있어 심사·QA 때 확인이 번거롭다.
    // 여기서는 PIN 없이 바로 띄운다 (이슈 #69 화면 검수용).
    ('아이 홈 · 일과 목록', Routes.child),
    ('아이 · 별 모으기', Routes.childStars),
    ('아이 · 보상', Routes.childReward),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: [
        for (final (label, route) in _destinations)
          ListTile(
            dense: true,
            title: Text(label),
            onTap: () {
              onClose();
              onNavigate(route);
            },
          ),
      ],
    );
  }
}


class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: onTap,
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            child: SelectableText(value, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
