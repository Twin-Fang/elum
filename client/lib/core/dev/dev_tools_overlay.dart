import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
import 'dev_log_file.dart';
import 'dev_state_dump.dart';
import 'dev_tools_visibility.dart';

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

    // 숨기기를 누르면 이번 실행 동안 버튼이 사라진다.
    // 되살리려면 작업관리자에서 앱을 완전히 종료했다 켠다 (이슈 #219).
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

enum _DevView { menu, logs, status, navigate, confirmReset, confirmLogout, dump }

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
      _DevView.confirmLogout => '로그아웃할까요?',
      _DevView.dump => '상태 덤프',
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
        _DevView.confirmLogout => _ConfirmLogoutView(
            onCancel: () => setState(() => _view = _DevView.menu),
            onDone: widget.onClose,
            onNavigate: widget.onNavigate,
          ),
        _DevView.dump => const _DumpView(),
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
        const Divider(height: 1),
        _Tile(
          icon: Icons.logout,
          label: '로그아웃',
          subtitle: '계정은 남기고 세션만 끊는다',
          onTap: () => widget.onSelect(_DevView.confirmLogout),
        ),
        const Divider(height: 1),
        // 로그 용량은 실시간으로 바뀐다 — 얼마나 찼는지 여기서 바로 보인다
        ValueListenableBuilder<int>(
          valueListenable: DevLogFile.sizeBytes,
          builder: (context, bytes, _) => _Tile(
            icon: Icons.download_outlined,
            label: '상태 덤프 내보내기',
            subtitle: '저장값·세션·설정·로그를 파일 하나로 '
                '(${DevStateDump.formatBytes(bytes)} / 2.00 MB)',
            onTap: () => widget.onSelect(_DevView.dump),
          ),
        ),
        _Tile(
          icon: Icons.visibility_off_outlined,
          label: '디버깅 버튼 숨기기',
          subtitle: '앱을 완전히 종료했다 켜면 다시 보인다',
          onTap: () {
            DevToolsVisibility.hide();
            widget.onSelect(_DevView.menu);
          },
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
                    // 서버 계정까지 지운다. 실패하면 로컬도 그대로 남는다 (이슈 #187) —
                    // 개발 도구라 여기서는 결과를 따지지 않고 로그인으로 보낸다.
                    await ref.read(authRepositoryProvider).deleteAccount();
                    // 메모리 상태도 비운다 — 저장소만 지우면 화면이 이전 값을 들고 있다.
                    // routineFlow(방금 만든 일과)·myRoutines(서버 조회 캐시)를 함께 비우지
                    // 않으면 재가입 후 홈에 이전 계정 일과가 그대로 노출된다 (이슈 #91).
                    ref.read(routineFlowProvider.notifier).reset();
                    ref.invalidate(myRoutinesProvider);
                    ref.invalidate(onboardingProvider);
                    if (!context.mounted) return;
                    onDone();
                    // 계정이 사라졌으니 로그인부터 다시 한다.
                    onNavigate(Routes.login);
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

/// 로그아웃 확인 — 계정은 남기고 세션만 끊는다 (이슈 #219).
///
/// 회원삭제는 되돌릴 수 없어 테스트 중 계정을 계속 새로 만들어야 했다.
/// 로그인 흐름만 다시 밟고 싶을 때 쓴다.
class _ConfirmLogoutView extends ConsumerWidget {
  const _ConfirmLogoutView({
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
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '계정은 그대로 남습니다.\n세션만 끊고 로그인 화면으로 갑니다.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(onPressed: onCancel, child: const Text('취소')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    await ref.read(authRepositoryProvider).logout();
                    // 메모리에 남은 이전 계정 값도 비운다 (회원삭제와 같은 이유, 이슈 #91)
                    ref.read(routineFlowProvider.notifier).reset();
                    ref.invalidate(myRoutinesProvider);
                    ref.invalidate(onboardingProvider);
                    if (!context.mounted) return;
                    onDone();
                    onNavigate(Routes.login);
                  },
                  child: const Text('로그아웃'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 상태 덤프 — 내부 값을 전부 모아 보여주고, 복사·파일 내보내기를 준다 (이슈 #219).
///
/// QA가 문제를 만난 자리에서 그대로 넘길 수 있게 하는 것이 목적이다.
/// 화면 캡처만으로는 어떤 값이 들어 있었는지 알 수 없다.
class _DumpView extends StatefulWidget {
  const _DumpView();

  @override
  State<_DumpView> createState() => _DumpViewState();
}

class _DumpViewState extends State<_DumpView> {
  String? _summary;
  String? _message;
  bool _busy = false;

  /// ⚠️ `initState`가 아니라 여기서 읽는다.
  ///
  /// 덤프는 `MediaQuery`(화면 크기·글꼴 배율·다크모드)를 본다. `initState`에서
  /// 상속 위젯을 읽으면 Flutter가 막는다 — 실제로 첫 구현에서
  /// `[기기] (수집 실패: dependOnInheritedWidgetOfExactType<MediaQuery>() was
  /// called before initState() completed)`가 찍혔다.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_summary == null) _load();
  }

  Future<void> _load() async {
    // 요약만 먼저 보여준다. 로그 전체(최대 2MB)를 화면에 그리면 느리다.
    final text = await DevStateDump.summary(context);
    if (mounted) setState(() => _summary = text);
  }

  /// 로그까지 붙인 전체를 만든다. 복사·내보내기가 공유한다.
  Future<String> _full() => DevStateDump.full(mounted ? context : null);

  Future<void> _copy() async {
    setState(() => _busy = true);
    try {
      await Clipboard.setData(ClipboardData(text: await _full()));
      _say('클립보드에 복사했습니다');
    } catch (e) {
      _say('복사하지 못했습니다: $e');
    }
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${DevStateDump.fileName()}');
      await file.writeAsString(await _full());
      // 공유 시트를 띄운다. 사용자가 취소해도 예외가 아니라 그냥 닫힌다.
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: 'elum 디버그 덤프'),
      );
      _say('내보냈습니다: ${file.path.split('/').last}');
    } catch (e) {
      _say('내보내지 못했습니다: $e');
    }
  }

  void _say(String m) {
    if (mounted) setState(() {
      _busy = false;
      _message = m;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_summary == null) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _copy,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('복사'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _export,
                  icon: const Icon(Icons.ios_share, size: 18),
                  label: const Text('내보내기'),
                ),
              ),
            ],
          ),
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(_message!, style: const TextStyle(fontSize: 12)),
          ),
        const SizedBox(height: 8),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SelectableText(
              _summary!,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
      ],
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
    // 역할 선택 (이슈 #212). 정식 경로는 로그인 → 약관 → 여기다.
    // 실기기 검수에서 매번 소셜 로그인을 다시 하지 않도록 지름길을 둔다.
    ('역할 선택', Routes.roleSelect),
    // 연결 암호 두 화면 (이슈 #205). 정식으로는 역할 선택에서 이룸이를 고르면
    // 열리지만, 두 화면을 따로 확인할 때가 있어 남겨 둔다.
    ('연결 · 암호 만들기(보호자)', Routes.linkCode),
    ('연결 · 암호 넣기(이룸이)', Routes.linkEnter),
    // 아이 모드는 PIN을 거쳐야 들어갈 수 있어 심사·QA 때 확인이 번거롭다.
    // 여기서는 PIN 없이 바로 띄운다 (이슈 #69 화면 검수용).
    ('이룸이 홈 · 일과 목록', Routes.child),
    ('이룸이 · 별 모으기', Routes.childStars),
    ('이룸이 · 보상', Routes.childReward),
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
