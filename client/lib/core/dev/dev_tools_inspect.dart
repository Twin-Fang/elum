part of 'dev_tools_overlay.dart';

/// 상태 덤프 — 내부 값을 전부 모아 보여주고, 복사·파일 내보내기를 준다.
///
/// 검수자가 문제를 만난 자리에서 그대로 넘길 수 있게 하는 것이 목적이다.
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
  /// 상속 위젯을 읽으면 Flutter가 막는다 — 실제로 첫 구현에서 이것이 찍혔다.
  ///
  /// ```text
  /// [기기] (수집 실패: dependOnInheritedWidgetOfExactType<MediaQuery>() was
  /// called before initState() completed)
  /// ```
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
    if (!mounted) return;
    setState(() {
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
        // 존재 여부만 조회해 암호 검증값이 개발 화면에도 노출되지 않게 한다
        FutureBuilder<bool>(
          future: storage.hasPin(),
          builder: (context, snap) => _Row(
            'PIN',
            (snap.data ?? false) ? '설정됨' : '(없음)',
          ),
        ),
        const SizedBox(height: 16),
        const Text('설정값', style: TextStyle(fontWeight: FontWeight.bold)),
        _Row('API', AppConfig.apiBaseUrl),
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
    // 약관. 로그인 직후에만 지나가는 화면이라 다시 보려면
    // 매번 로그아웃해야 한다. 상태가 둘(미동의·전체동의)이라 확인할 일이 잦다.
    ('약관 동의', Routes.consent),
    ('온보딩 · 이름', Routes.onboardingName),
    ('온보딩 · 목표', Routes.onboardingGoals),
    ('온보딩 · 캐릭터', Routes.onboardingCharacter),
    ('온보딩 · 그림 방식', Routes.onboardingImageStyle),
    ('온보딩 · PIN', Routes.onboardingPin),
    ('일과 · 보상 정하기', Routes.routineReward),
    ('보호자 홈', Routes.guardian),
    // 역할 선택. 정식 경로는 로그인 → 약관 → 여기다.
    // 실기기 검수에서 매번 소셜 로그인을 다시 하지 않도록 지름길을 둔다.
    ('역할 선택', Routes.roleSelect),
    // 연결 암호 두 화면. 정식으로는 역할 선택에서 이룸이를 고르면
    // 열리지만, 두 화면을 따로 확인할 때가 있어 남겨 둔다.
    ('연결 · 암호 만들기(보호자)', Routes.linkCode),
    ('연결 · 암호 넣기(이룸이)', Routes.linkEnter),
    // 아이 모드는 PIN을 거쳐야 들어갈 수 있어 심사·검수 때 확인이 번거롭다.
    // 여기서는 PIN 없이 바로 띄운다.
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
