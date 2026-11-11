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
    required this.currentLocation,
  });

  final VoidCallback onClose;
  final void Function(String route) onNavigate;
  final BuildContext? Function() navigatorContext;

  /// 지금 라우터 위치 (상태 복사에 담음)
  final String? Function() currentLocation;

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
  networkFault('요청 실패 흉내'),
  navigate('화면 이동'),
  locale('언어 강제'),
  logs('로그'),
  dump('전체 값 보기'),
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
                  color: _DevPalette.sheetBackground,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _Handle(),
                      _header(),
                      // 상단 안전영역 여백이 목록에 한 번 더 붙어 제목 아래 빈 칸이 생기지 않게 지움
                      Flexible(
                        child: MediaQuery.removePadding(
                          context: context,
                          removeTop: true,
                          child: _view == _DevView.menu ? _body() : _SubViewCard(child: _body()),
                        ),
                      ),
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
            child: Column(
              children: [
                Text(
                  _view.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _DevPalette.title),
                ),
                if (_view == _DevView.menu)
                  const Text(
                    '테스트 빌드 전용 · 이 기기에만 적용',
                    style: TextStyle(fontSize: 11, color: _DevPalette.caption),
                  ),
              ],
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
            currentLocation: widget.currentLocation,
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
        _DevView.dump => _DumpView(currentLocation: widget.currentLocation),
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

/// 하위 화면 틀: 회색 시트 위 흰 둥근 카드
class _SubViewCard extends StatelessWidget {
  const _SubViewCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ColoredBox(color: _DevPalette.groupBackground, child: child),
      ),
    );
  }
}
