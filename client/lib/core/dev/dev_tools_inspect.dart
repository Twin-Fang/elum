part of 'dev_tools_overlay.dart';

/// 전체 값 보기: 내부 값을 전부(토큰 전문) 화면에 보이고, 로그 파일까지 담아 내보냄
///
/// 채팅에 붙일 짧은 보고서는 메뉴 맨 위 `상태·로그 복사` 가 맡음 (토큰 가림)
class _DumpView extends ConsumerStatefulWidget {
  const _DumpView({required this.currentLocation});

  final String? Function() currentLocation;

  @override
  ConsumerState<_DumpView> createState() => _DumpViewState();
}

class _DumpViewState extends ConsumerState<_DumpView> {
  String? _summary;
  String? _message;
  bool _isBusy = false;

  /// `initState` 가 아니라 여기서 읽음 (덤프가 MediaQuery 를 봄 > initState 에서는 Flutter 가 막음)
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_summary == null) _load();
  }

  // 요약만 먼저 보임 (로그 전체 최대 2MB 를 그리면 느림)
  Future<void> _load() async {
    final text = await DevStateDump.summary(
      context: context,
      liveSections: _readLiveSections(ref, widget.currentLocation),
    );
    if (mounted) setState(() => _summary = text);
  }

  Future<void> _onExportPressed() async {
    setState(() => _isBusy = true);
    final (message, _) = await _exportFullDump(context, ref, widget.currentLocation);
    if (!mounted) return;
    setState(() {
      _isBusy = false;
      _message = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    if (summary == null) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isBusy ? null : _onExportPressed,
              icon: const Icon(Icons.ios_share, size: 18),
              label: const Text('로그 파일까지 전부 내보내기'),
            ),
          ),
        ),
        _Message(_message ?? '토큰 전문이 들어 있어요. 채팅·이슈에는 메뉴 맨 위 `상태·로그 복사` 를 쓰세요'),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SelectableText(
              summary,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }
}

/// 이번 실행 로그 실시간 보기 (새 줄이 아래, 열면 맨 아래부터)
class _LogViewer extends StatefulWidget {
  const _LogViewer();

  @override
  State<_LogViewer> createState() => _LogViewerState();
}

class _LogViewerState extends State<_LogViewer> {
  // 이 패널은 Navigator 밖이라 SnackBar 가 안 뜸 > 결과를 줄로 보임
  String? _message;

  Future<void> _onCopyPressed() async {
    final lines = DevLogBuffer.lines;
    final recentLines = lines.length > DevStateReport.logLineCount
        ? lines.sublist(lines.length - DevStateReport.logLineCount)
        : lines;
    await Clipboard.setData(ClipboardData(text: recentLines.join('\n')));
    if (!mounted) return;
    setState(() => _message = '최근 로그 ${recentLines.length}줄을 복사했어요');
  }

  void _onClearPressed() {
    DevLogBuffer.clear();
    setState(() => _message = '화면 로그를 비웠어요 (파일 기록은 남음)');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Message(_message ?? '새 로그가 아래에 쌓여요'),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: _onCopyPressed,
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('최근 ${DevStateReport.logLineCount}줄 복사'),
            ),
            TextButton.icon(
              onPressed: _onClearPressed,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('비우기'),
            ),
          ],
        ),
        const Divider(height: 1),
        Flexible(
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
              // reverse: 열자마자 최신 줄이 보이게 (index 0 = 최신)
              return ListView.builder(
                shrinkWrap: true,
                reverse: true,
                padding: const EdgeInsets.all(12),
                itemCount: lines.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: SelectableText(
                    lines[lines.length - 1 - index],
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
    ('온보딩 · 예시 분류', Routes.onboardingExampleCategories),
    ('온보딩 · 캐릭터', Routes.onboardingCharacter),
    ('온보딩 · 그림 방식', Routes.onboardingImageStyle),
    ('온보딩 · PIN', Routes.onboardingPin),
    ('일과 · 보상 정하기', Routes.routineReward),
    ('보호자 홈', Routes.guardian),
    // 주간 리포트(Pro). Free 는 입구가 없어 요금제 흉내와 함께 바로 띄워 본다
    ('보호자 · 주간 리포트', Routes.guardianWeeklyReport),
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
