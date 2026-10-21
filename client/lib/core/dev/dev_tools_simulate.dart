part of 'dev_tools_overlay.dart';

/// 앱 상태 흉내: 고르면 서버 대신 만든 상태로 게이트를 다시 그림
/// 업데이트 권유는 보호자·이룸이 홈에 들어갈 때 뜨므로 오늘 기록을 지우고 앱을 다시 띄움
class _AppStatusSimulationView extends ConsumerWidget {
  const _AppStatusSimulationView({required this.onRestartApp});

  final void Function(BuildContext context) onRestartApp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder<DevAppStatusSimulation>(
      valueListenable: DevSimulation.appStatus,
      builder: (context, selected, _) => ListView(
        shrinkWrap: true,
        children: [
          const _Message('서버에 묻지 않고 이 기기에서만 바꿉니다. 앱을 끄면 꺼집니다.\n'
              '점검·강제 업데이트 화면에서도 디버깅 버튼으로 돌아와 끌 수 있습니다.'),
          for (final simulation in DevAppStatusSimulation.values)
            _ChoiceTile(
              label: simulation.label,
              isSelected: simulation == selected,
              onTap: () => _select(context, ref, simulation),
            ),
        ],
      ),
    );
  }

  Future<void> _select(BuildContext context, WidgetRef ref, DevAppStatusSimulation simulation) async {
    DevSimulation.appStatus.value = simulation;
    AppLogger.info('[dev simulation] app status : ${simulation.name}');
    if (simulation == DevAppStatusSimulation.suggestUpdate) {
      // 하루 한 번 기록을 지우고 홈부터 다시 (권유는 홈 진입 때 판단)
      await ref.read(localStorageProvider).setUpdateSuggestionShownRecord('');
      if (context.mounted) onRestartApp(context);
      return;
    }
    ref.invalidate(appStatusProvider);
  }
}

/// 공지 흉내: 숨긴 공지 다시 보기, 견본 공지 3종을 실제 공지 팝업으로
class _NoticeSimulationView extends ConsumerWidget {
  const _NoticeSimulationView({
    required this.onClose,
    required this.onRestartApp,
    required this.navigatorContext,
  });

  final VoidCallback onClose;
  final void Function(BuildContext context) onRestartApp;
  final BuildContext? Function() navigatorContext;

  // 견본 공지 3종: 글만, 버튼, 긴 글 (id 는 숨김 기록과 겹치지 않게 dev- 로 시작)
  static final _sampleNotices = <AppNotice>[
    const AppNotice(
      id: 'dev-sample-text',
      revision: 1,
      title: '**새 기능**을 소개해요',
      body: '견본 공지예요. 글만 있는 공지가 이렇게 보여요.',
    ),
    AppNotice(
      id: 'dev-sample-button',
      revision: 1,
      title: '설문에 참여해 주세요',
      body: '버튼이 있는 견본 공지예요. 버튼을 누르면 브라우저가 열려요.',
      button: NoticeButton(label: '설문 열기', url: Uri.parse('https://example.com')),
    ),
    AppNotice(
      id: 'dev-sample-long',
      revision: 1,
      title: '아주 긴 제목이 두 줄을 넘어가면 어떻게 보이는지 확인하는 견본 공지예요',
      body: List.filled(12, '긴 본문이 스크롤되는지 확인하는 견본 문장이에요.').join('\n'),
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      shrinkWrap: true,
      children: [
        _Tile(
          icon: Icons.refresh,
          label: '숨긴 공지 다시 보기',
          subtitle: '"보지 않기" 기록을 지우고 앱을 다시 띄움 > 보호자 홈에서 서버 공지를 다시 받음',
          onTap: () async {
            await ref.read(localStorageProvider).clearNoticeHidden();
            if (context.mounted) onRestartApp(context);
          },
        ),
        const _Section('견본 공지 (서버에 올리지 않음)'),
        for (final notice in _sampleNotices)
          _Tile(
            icon: Icons.campaign_outlined,
            label: notice.title.replaceAll('**', ''),
            subtitle: notice.button == null ? '글만' : '버튼 있음',
            onTap: () => _showSample(notice),
          ),
        const _Message('진짜 공지 흐름(노출 기간·플랫폼·우선순위)은 로컬 서버 관리자 화면 /admin/notices 에서 올려 확인합니다.'),
      ],
    );
  }

  // 시트를 닫고 라우터 화면 위에 띄움 (보지 않기를 골라도 기록하지 않음)
  Future<void> _showSample(AppNotice notice) async {
    onClose();
    final context = navigatorContext();
    if (context == null || !context.mounted) return;
    await showNoticePopup(context, notice, hideDays: NoticeFeed.defaultHideDays);
  }
}

/// 푸시 흉내: 종류별로 실제 배너(로컬 알림) 띄우기, 또는 누른 것처럼 바로 이동
/// 서버 알림 기록이 없어 읽음 처리는 하지 않음 (notificationId 없음)
class _PushSimulationView extends ConsumerWidget {
  const _PushSimulationView({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      shrinkWrap: true,
      children: [
        const _Message('보호자로 로그인한 상태에서만 이동합니다.\n'
            '배너는 알림 권한이 있어야 뜹니다. 이야기 알림은 글 id 가 없어 글 화면이 빈 상태로 열립니다.'),
        for (final type in NotificationType.values) _pushRow(context, ref, type.wire, type.name),
        // 앱이 모르는 종류 > 알림 목록으로 가는지
        _pushRow(context, ref, 'UNKNOWN_TYPE', '모르는 종류 (알림 목록으로)'),
      ],
    );
  }

  Widget _pushRow(BuildContext context, WidgetRef ref, String typeWire, String label) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      subtitle: Text(typeWire, style: const TextStyle(fontSize: 11)),
      trailing: Wrap(
        spacing: 4,
        children: [
          TextButton(
            onPressed: () => _showBanner(ref, typeWire, label),
            child: const Text('배너'),
          ),
          TextButton(
            onPressed: () => _openAsTapped(ref, typeWire, label),
            child: const Text('바로 이동'),
          ),
        ],
      ),
    );
  }

  PushMessage _sampleMessage(WidgetRef ref, String typeWire, String label) => PushMessage(
    data: {
      'type': typeWire,
      // 이룸이 관련 알림이 지금 고른 이룸이를 가리키게
      'profileId': ?ref.read(localStorageProvider).selectedProfileId,
    },
    title: '[흉내] $label',
    body: '개발자 도구가 띄운 견본 푸시예요.',
  );

  Future<void> _showBanner(WidgetRef ref, String typeWire, String label) async {
    final message = _sampleMessage(ref, typeWire, label);
    onClose();
    await ref.read(pushMessageRouterProvider).showBannerAsReceived(message);
  }

  void _openAsTapped(WidgetRef ref, String typeWire, String label) {
    final message = _sampleMessage(ref, typeWire, label);
    onClose();
    ref.read(pushMessageRouterProvider).openAsTapped(message);
  }
}

/// 실패 흉내: 고르면 다음 요청부터 그 실패로 끝남 (토큰 갱신 요청은 제외)
class _NetworkFaultView extends StatelessWidget {
  const _NetworkFaultView();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DevNetworkFault>(
      valueListenable: DevSimulation.networkFault,
      builder: (context, selected, _) => ListView(
        shrinkWrap: true,
        children: [
          const _Message('이 기기의 요청을 서버로 보내지 않고 실패시킵니다. 앱을 끄면 꺼집니다.\n'
              '화면이 깨지지 않고 에러 코드와 다시 시도가 보이는지 확인합니다.'),
          for (final fault in DevNetworkFault.values)
            _ChoiceTile(
              label: fault.label,
              isSelected: fault == selected,
              onTap: () {
                DevSimulation.networkFault.value = fault;
                AppLogger.info('[dev simulation] network fault : ${fault.name}');
              },
            ),
        ],
      ),
    );
  }
}
