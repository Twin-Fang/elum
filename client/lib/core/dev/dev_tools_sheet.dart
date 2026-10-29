part of 'dev_tools_overlay.dart';

/// 개발자 도구 시트 — Overlay에 직접 올라간다.
///
/// `showModalBottomSheet`를 쓰지 않으므로 Navigator가 필요 없다.
/// 하위 화면 전환도 라우팅 대신 내부 상태로 처리한다.
class _DevToolsSheet extends StatefulWidget {
  const _DevToolsSheet({
    required this.onClose,
    required this.onNavigate,
    required this.navigatorContext,
  });

  final VoidCallback onClose;
  final void Function(String route) onNavigate;
  final BuildContext? Function() navigatorContext;

  @override
  State<_DevToolsSheet> createState() => _DevToolsSheetState();
}

/// 시트 화면: 메뉴 + 하위 화면 12개 (제목은 [title])
enum _DevView {
  menu('개발자 도구'),
  server('서버 바꾸기'),
  testAccounts('테스트 계정'),
  appStatus('앱 상태 흉내'),
  notice('공지 흉내'),
  push('푸시 알림 흉내'),
  networkFault('실패 흉내'),
  navigate('화면 이동'),
  locale('언어 강제'),
  logs('로그'),
  dump('상태 덤프'),
  confirmReset('회원을 삭제할까요?'),
  confirmLogout('로그아웃할까요?');

  const _DevView(this.title);

  final String title;
}

class _DevToolsSheetState extends State<_DevToolsSheet> {
  _DevView _view = _DevView.menu;

  void _backToMenu() => setState(() => _view = _DevView.menu);

  /// 시트를 닫고 앱 트리를 다시 만듦 (서버 바꾸기, 공지·코치마크 다시 보기)
  void _closeAndRestartApp(BuildContext context) {
    widget.onClose();
    AppRestart.restart(context);
  }

  @override
  Widget build(BuildContext context) {
    // 입력칸(서버 주소)에 키보드가 올라오면 시트를 그만큼 올린다
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 시트 밖을 누르면 닫힌다
          Positioned.fill(
            child: Semantics(
              container: true,
              button: true,
              label: '개발자 도구 닫기',
              child: GestureDetector(
                onTap: widget.onClose,
                child: Container(color: Colors.black.withValues(alpha: 0.4)),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: keyboardInset),
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxHeight: (MediaQuery.sizeOf(context).height - keyboardInset) * 0.85,
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
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          // 하위 화면에서는 메뉴로 돌아가는 버튼을 준다
          if (_view != _DevView.menu)
            IconButton(
              // 아이콘만 있는 버튼이라 이름을 준다. tooltip 은 쓰지 않는다 —
              // 이 패널은 Navigator 바깥에 떠서 Tooltip 이 찾을 Overlay 가 없다.
              icon: const Icon(
                Icons.arrow_back,
                size: 20,
                semanticLabel: '메뉴로 돌아가기',
              ),
              onPressed: _backToMenu,
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: Text(
              _view.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20, semanticLabel: '닫기'),
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _body() => switch (_view) {
        _DevView.menu => _DevMenu(
            onSelect: (v) => setState(() => _view = v),
            onRestartApp: _closeAndRestartApp,
          ),
        _DevView.server => _ServerView(onRestartApp: _closeAndRestartApp),
        _DevView.testAccounts => _TestAccountView(
            onClose: widget.onClose,
            onNavigate: widget.onNavigate,
          ),
        _DevView.appStatus => _AppStatusSimulationView(onRestartApp: _closeAndRestartApp),
        _DevView.notice => _NoticeSimulationView(
            onClose: widget.onClose,
            onRestartApp: _closeAndRestartApp,
            navigatorContext: widget.navigatorContext,
          ),
        _DevView.push => _PushSimulationView(onClose: widget.onClose),
        _DevView.networkFault => const _NetworkFaultView(),
        _DevView.navigate => _NavigateView(
            onClose: widget.onClose,
            onNavigate: widget.onNavigate,
          ),
        _DevView.locale => const _LocaleView(),
        _DevView.logs => const _LogViewer(),
        _DevView.dump => const _DumpView(),
        _DevView.confirmReset => _ConfirmResetView(
            onCancel: _backToMenu,
            onDone: widget.onClose,
            onNavigate: widget.onNavigate,
          ),
        _DevView.confirmLogout => _ConfirmLogoutView(
            onCancel: _backToMenu,
            onDone: widget.onClose,
            onNavigate: widget.onNavigate,
          ),
      };
}

/// 기능 목록: 묶음 6개 (서버와 계정, 이 기기에서만 흉내, 화면과 언어, 기록, 크래시 보내기, 위험)
class _DevMenu extends ConsumerStatefulWidget {
  const _DevMenu({required this.onSelect, required this.onRestartApp});

  final ValueChanged<_DevView> onSelect;
  final void Function(BuildContext context) onRestartApp;

  @override
  ConsumerState<_DevMenu> createState() => _DevMenuState();
}

class _DevMenuState extends ConsumerState<_DevMenu> {
  @override
  Widget build(BuildContext context) {
    final serverLabel = AppConfig.isProductionApiServer ? '운영' : AppConfig.apiBaseUrl;
    return ListView(
      shrinkWrap: true,
      children: [
        const _Section('서버와 계정'),
        _Tile(
          icon: Icons.dns_outlined,
          label: '서버 바꾸기',
          subtitle: '지금: $serverLabel',
          onTap: () => widget.onSelect(_DevView.server),
        ),
        _Tile(
          icon: Icons.badge_outlined,
          label: '테스트 계정',
          subtitle: AppConfig.isProductionApiServer
              ? '운영 서버에서는 쓸 수 없음 (서버를 먼저 바꾸기)'
              : '소셜 로그인 없이 새 계정 만들기·바꾸기',
          onTap: () => widget.onSelect(_DevView.testAccounts),
        ),
        _Tile(
          icon: Icons.logout,
          label: '로그아웃',
          subtitle: '계정은 남기고 세션만 끊는다',
          onTap: () => widget.onSelect(_DevView.confirmLogout),
        ),
        const _Section('이 기기에서만 흉내 (다른 사용자 영향 없음)'),
        _Tile(
          icon: Icons.system_update_outlined,
          label: '앱 상태',
          subtitle: '업데이트 권유·강제 업데이트·점검 — 지금: ${DevSimulation.appStatus.value.label}',
          onTap: () => widget.onSelect(_DevView.appStatus),
        ),
        _Tile(
          icon: Icons.campaign_outlined,
          label: '공지',
          subtitle: '숨긴 공지 다시 보기·견본 공지 띄우기',
          onTap: () => widget.onSelect(_DevView.notice),
        ),
        _Tile(
          icon: Icons.notifications_active_outlined,
          label: '푸시 알림',
          subtitle: '종류별 배너 띄우기·눌러서 이동',
          onTap: () => widget.onSelect(_DevView.push),
        ),
        _Tile(
          icon: Icons.wifi_off_outlined,
          label: '실패',
          subtitle: '네트워크 끊김·지연·서버 오류 — 지금: ${DevSimulation.networkFault.value.label}',
          onTap: () => widget.onSelect(_DevView.networkFault),
        ),
        _Tile(
          icon: Icons.restart_alt,
          label: '처음 한 번만 보이는 것 다시 보기',
          subtitle: '코치마크·공지 숨김·업데이트 권유 기록을 지우고 앱을 다시 띄움',
          onTap: _resetFirstTimeRecords,
        ),
        const _Section('화면과 언어'),
        _Tile(
          icon: Icons.navigation_outlined,
          label: '화면 이동',
          subtitle: '온보딩 단계·보호자 홈·이룸이 화면',
          onTap: () => widget.onSelect(_DevView.navigate),
        ),
        _Tile(
          icon: Icons.language,
          label: '언어 강제',
          subtitle: '기기 언어와 무관하게 앱 언어를 고른다',
          onTap: () => widget.onSelect(_DevView.locale),
        ),
        // 스위치가 제목과 따로 떨어져 이름 없이 읽히지 않게 한 노드로 묶는다
        MergeSemantics(
          child: ListTile(
            leading: const Icon(Icons.speed),
            title: const Text('온보딩 건너뛰기'),
            subtitle: const Text(
              '이번 실행만 (앱을 끄면 .env 값으로 돌아감)',
              style: TextStyle(fontSize: 12),
            ),
            trailing: Switch(
              value: AppConfig.skipOnboarding,
              onChanged: (value) => setState(() => AppConfig.skipOnboarding = value),
            ),
          ),
        ),
        const _Section('기록'),
        _Tile(
          icon: Icons.article_outlined,
          label: '로그 보기',
          subtitle: '최근 ${DevLogBuffer.maxLines}줄',
          onTap: () => widget.onSelect(_DevView.logs),
        ),
        // 로그 용량은 실시간으로 바뀐다 — 얼마나 찼는지 여기서 바로 보인다
        ValueListenableBuilder<int>(
          valueListenable: DevLogFile.sizeBytes,
          builder: (context, bytes, _) => _Tile(
            icon: Icons.download_outlined,
            label: '상태 덤프',
            subtitle: '저장값·세션·설정·로그 보기와 파일 내보내기 '
                '(${DevStateDump.formatBytes(bytes)} / 2.00 MB)',
            onTap: () => widget.onSelect(_DevView.dump),
          ),
        ),
        _Tile(
          icon: Icons.visibility_off_outlined,
          label: '디버깅 버튼 숨기기',
          subtitle: '앱을 완전히 종료했다 켜면 다시 보인다',
          onTap: DevToolsVisibility.hide,
        ),
        const _Section('크래시 보내기'),
        const _CrashReportingTiles(),
        const _Section('위험'),
        _Tile(
          icon: Icons.person_remove_outlined,
          label: '회원삭제',
          subtitle: '서버 계정과 이 기기 저장값을 지우고 처음부터',
          isDestructive: true,
          onTap: () => widget.onSelect(_DevView.confirmReset),
        ),
      ],
    );
  }

  // 코치마크·공지 숨김·업데이트 권유 기록 초기화 > 앱 다시 띄우기 (화면들이 처음부터 다시 판단)
  Future<void> _resetFirstTimeRecords() async {
    final storage = ref.read(localStorageProvider);
    await storage.resetCoachMarks();
    await storage.clearNoticeHidden();
    await storage.setUpdateSuggestionShownRecord('');
    if (!mounted) return;
    widget.onRestartApp(context);
  }
}
