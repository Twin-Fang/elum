import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  const DevToolsOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<DevToolsOverlay> createState() => _DevToolsOverlayState();
}

class _DevToolsOverlayState extends State<DevToolsOverlay> {
  /// 버튼 위치. null이면 첫 레이아웃에서 우하단으로 잡는다.
  Offset? _position;

  static const _buttonSize = 48.0;

  /// 화면 가장자리 최소 여백 — 버튼이 완전히 잘려 못 누르는 상황을 막는다
  static const _edgeMargin = 8.0;

  @override
  Widget build(BuildContext context) {
    // 플래그가 꺼져 있으면 아무것도 얹지 않는다.
    // 위젯 트리에 추가되는 것이 없어 런타임 비용이 0이다.
    if (!AppConfig.showDevTools) return widget.child;

    return Stack(
      children: [
        widget.child,
        LayoutBuilder(
          builder: (context, constraints) {
            final maxX = constraints.maxWidth - _buttonSize - _edgeMargin;
            final maxY = constraints.maxHeight - _buttonSize - _edgeMargin;

            // 첫 프레임 기본 위치: 우하단. 하단 CTA 버튼을 가리지 않도록 조금 띄운다.
            final pos = _position ?? Offset(maxX, maxY - 80);
            final clamped = Offset(
              pos.dx.clamp(_edgeMargin, maxX),
              pos.dy.clamp(_edgeMargin, maxY),
            );

            return Positioned(
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
                onTap: () => _openPanel(context),
              ),
            );
          },
        ),
      ],
    );
  }

  void _openPanel(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _DevToolsPanel(),
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

/// 기능 패널.
class _DevToolsPanel extends ConsumerWidget {
  const _DevToolsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Handle(),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '개발자 도구',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            _Tile(
              icon: Icons.refresh,
              label: '온보딩 초기화',
              subtitle: '저장값을 지우고 시작 화면부터 다시',
              onTap: () => _confirmReset(context, ref),
            ),
            _Tile(
              icon: Icons.article_outlined,
              label: '로그 보기',
              subtitle: '최근 ${DevLogBuffer.maxLines}줄',
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const _LogViewer(),
                );
              },
            ),
            _Tile(
              icon: Icons.info_outline,
              label: '현재 상태',
              subtitle: '저장값·설정값 확인',
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const _StatusView(),
                );
              },
            ),
            _Tile(
              icon: Icons.navigation_outlined,
              label: '화면 이동',
              subtitle: '온보딩 단계·보호자 홈',
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => const _NavigateView(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 실수로 눌러 저장값이 날아가지 않도록 한 번 확인한다.
  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('온보딩을 초기화할까요?'),
        content: const Text('저장된 호칭·목표·캐릭터·PIN이 모두 지워집니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('초기화'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await ref.read(localStorageProvider).clearAll();
    // 메모리 상태도 함께 비운다 — 저장소만 지우면 화면이 이전 값을 계속 들고 있다
    ref.invalidate(onboardingProvider);

    if (!context.mounted) return;
    Navigator.pop(context);
    context.go(Routes.splash);
  }
}

/// 최근 로그를 보여준다. 복사 버튼 포함.
class _LogViewer extends StatelessWidget {
  const _LogViewer();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          const _Handle(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text('로그', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: DevLogBuffer.asText()),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
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
          Expanded(
            // 새 로그가 쌓이면 즉시 갱신한다
            child: ValueListenableBuilder<int>(
              valueListenable: DevLogBuffer.revision,
              builder: (context, _, __) {
                final lines = DevLogBuffer.lines;
                if (lines.isEmpty) {
                  return const Center(child: Text('아직 로그가 없어요'));
                }
                return ListView.builder(
                  controller: scrollController,
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
      ),
    );
  }
}

/// 저장값·설정값을 보여준다.
class _StatusView extends ConsumerWidget {
  const _StatusView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.read(localStorageProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      expand: false,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          const _Handle(),
          const SizedBox(height: 12),
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
          _Row('DLP 최소 지연', '${AppConfig.dlpMinDelay.inMilliseconds}ms'),
        ],
      ),
    );
  }
}

/// 화면 바로 이동.
class _NavigateView extends StatelessWidget {
  const _NavigateView();

  static const _destinations = <(String, String)>[
    ('시작', Routes.splash),
    ('온보딩 · 이름', Routes.onboardingName),
    ('온보딩 · 목표', Routes.onboardingGoals),
    ('온보딩 · 캐릭터', Routes.onboardingCharacter),
    ('온보딩 · PIN', Routes.onboardingPin),
    ('보호자 홈', Routes.guardian),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Handle(),
          const SizedBox(height: 12),
          for (final (label, route) in _destinations)
            ListTile(
              dense: true,
              title: Text(label),
              onTap: () {
                Navigator.pop(context);
                context.go(route);
              },
            ),
          const SizedBox(height: 12),
        ],
      ),
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
