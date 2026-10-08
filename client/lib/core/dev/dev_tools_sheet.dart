part of 'dev_tools_overlay.dart';

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

enum _DevView { menu, logs, status, navigate, confirmReset, confirmLogout, dump, locale }

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
      _DevView.locale => '언어 강제',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          // 하위 화면에서는 메뉴로 돌아가는 버튼을 준다
          if (_view != _DevView.menu)
            IconButton(
              // 아이콘만 있는 버튼이라 이름을 준다 (#339). tooltip 은 쓰지 않는다 —
              // 이 패널은 Navigator 바깥에 떠서 Tooltip 이 찾을 Overlay 가 없다.
              icon: const Icon(
                Icons.arrow_back,
                size: 20,
                semanticLabel: '메뉴로 돌아가기',
              ),
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
        _DevView.locale => const _LocaleView(),
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
        // 스위치가 제목과 따로 떨어져 이름 없이 읽히지 않게 한 노드로 묶는다 (#339)
        MergeSemantics(
          child: ListTile(
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
        _Tile(
          icon: Icons.language,
          label: '언어 강제',
          subtitle: '휴대폰 언어와 무관하게 앱 언어를 고른다 (QA·시연용)',
          onTap: () => widget.onSelect(_DevView.locale),
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
