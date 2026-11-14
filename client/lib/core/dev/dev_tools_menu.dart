part of 'dev_tools_overlay.dart';

/// 개발자 도구 첫 화면: 지금 상태 카드 + 묶음 6개
/// (자주 쓰는 것, 서버와 계정, 이 기기에서만 흉내, 기록, Firebase 보내기, 위험)
class _DevMenu extends ConsumerStatefulWidget {
  const _DevMenu({required this.onSelect, required this.onRestartApp, required this.currentLocation});

  final ValueChanged<_DevView> onSelect;
  final void Function(BuildContext context) onRestartApp;
  final String? Function() currentLocation;

  @override
  ConsumerState<_DevMenu> createState() => _DevMenuState();
}

class _DevMenuState extends ConsumerState<_DevMenu> {
  @override
  Widget build(BuildContext context) {
    final forcedLocale = ref.watch(devLocaleOverrideProvider);
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _StateOverviewCard(
          currentLocation: widget.currentLocation,
          onOpenFullView: () => widget.onSelect(_DevView.dump),
        ),
        _Group(
          title: '자주 쓰는 것',
          footer: '요금제 흉내·결제 화면·Pro 미리 보기·언어는 이 기기 화면만 바꿔요. 앱을 다시 켜면 원래대로 돌아가요',
          children: [
            const _PlanOverrideRow(),
            const _StoreForcedRow(),
            const _CreditPackSaleForcedRow(),
            const _ProTeaserForcedRow(),
            _Tile(
              icon: Icons.navigation_outlined,
              label: '화면 이동',
              subtitle: '온보딩 단계·보호자 홈·주간 리포트·이룸이 화면으로 바로',
              onTap: () => widget.onSelect(_DevView.navigate),
            ),
            _Tile(
              icon: Icons.language,
              label: '언어 강제',
              subtitle: '기기 언어와 상관없이 앱 언어 고르기',
              currentValueLabel: forcedLocale == null ? '기기 언어' : forcedLocale.toLanguageTag(),
              isValueChanged: forcedLocale != null,
              onTap: () => widget.onSelect(_DevView.locale),
            ),
            _Tile(
              icon: Icons.palette_outlined,
              label: '디자인 기반 미리 보기',
              subtitle: '공통 모션·작은 카드·하이라이트·보상 축하·3D 그림 세트 (#1407)',
              onTap: () => widget.onSelect(_DevView.designShowcase),
            ),
          ],
        ),
        _Group(
          title: '서버와 계정',
          children: [
            _Tile(
              icon: Icons.dns_outlined,
              label: '서버 바꾸기',
              subtitle: '${AppConfig.apiBaseUrl} · ${_apiBaseUrlSourceLabel(AppConfig.apiBaseUrlSource)}',
              currentValueLabel: AppConfig.isProductionApiServer ? '운영' : '운영 아님',
              isValueChanged: !AppConfig.isProductionApiServer,
              onTap: () => widget.onSelect(_DevView.server),
            ),
            _Tile(
              icon: Icons.badge_outlined,
              label: '테스트 계정',
              subtitle: AppConfig.isProductionApiServer ? '운영 서버에서는 못 씀 (서버를 먼저 바꾸기)' : '소셜 로그인 없이 새 계정 만들기·바꾸기',
              onTap: () => widget.onSelect(_DevView.testAccounts),
            ),
            _Tile(
              icon: Icons.logout,
              label: '로그아웃',
              subtitle: '계정은 남기고 이 기기 세션만 끊기',
              onTap: () => widget.onSelect(_DevView.confirmLogout),
            ),
          ],
        ),
        _Group(
          title: '이 기기에서만 흉내',
          footer: '다른 사용자·서버 값에는 영향 없어요',
          children: [
            _Tile(
              icon: Icons.system_update_outlined,
              label: '앱 상태',
              subtitle: '업데이트 권유·강제 업데이트·점검 화면',
              currentValueLabel: DevSimulation.appStatus.value == DevAppStatusSimulation.off
                  ? '끔'
                  : DevSimulation.appStatus.value.label,
              isValueChanged: DevSimulation.appStatus.value != DevAppStatusSimulation.off,
              onTap: () => widget.onSelect(_DevView.appStatus),
            ),
            _Tile(
              icon: Icons.wifi_off_outlined,
              label: '요청 실패',
              subtitle: '네트워크 끊김·응답 지연·서버 오류 500',
              currentValueLabel: DevSimulation.networkFault.value.label,
              isValueChanged: DevSimulation.networkFault.value != DevNetworkFault.off,
              onTap: () => widget.onSelect(_DevView.networkFault),
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
            _SwitchTile(
              icon: Icons.speed,
              label: '온보딩 건너뛰기',
              subtitle: '이번 실행만 (앱을 끄면 .env 값으로 돌아감)',
              isOn: AppConfig.skipOnboarding,
              onChanged: (value) => setState(() => AppConfig.skipOnboarding = value),
            ),
            _Tile(
              icon: Icons.restart_alt,
              label: '처음 한 번만 보이는 것 다시 보기',
              subtitle: '코치마크·공지 숨김·업데이트 권유 기록을 지우고 앱 다시 띄우기',
              onTap: _resetFirstTimeRecords,
            ),
          ],
        ),
        _Group(
          title: '기록',
          children: [
            ValueListenableBuilder<int>(
              valueListenable: DevLogBuffer.revision,
              builder: (context, _, _) => _Tile(
                icon: Icons.article_outlined,
                label: '로그 보기',
                subtitle: '이번 실행 로그를 실시간으로 (최근 ${DevLogBuffer.maxLines}줄)',
                currentValueLabel: '${DevLogBuffer.lines.length}줄',
                onTap: () => widget.onSelect(_DevView.logs),
              ),
            ),
            ValueListenableBuilder<int>(
              valueListenable: DevLogFile.sizeBytes,
              builder: (context, bytes, _) => _Tile(
                icon: Icons.inventory_2_outlined,
                label: '전체 값 보기',
                subtitle: '저장값·세션·설정 전부 (토큰 전문). 로그 파일 포함 내보내기',
                currentValueLabel: '로그 ${DevStateDump.formatBytes(bytes)}',
                onTap: () => widget.onSelect(_DevView.dump),
              ),
            ),
            const _Tile(
              icon: Icons.visibility_off_outlined,
              label: '디버깅 버튼 숨기기',
              subtitle: '앱을 완전히 껐다 켜면 다시 보여요',
              onTap: DevToolsVisibility.hide,
            ),
          ],
        ),
        const _Group(
          title: 'Firebase 보내기',
          footer: '켜 두면 앱을 꺼도 유지돼요',
          children: [_CrashReportingTiles(), _AnalyticsTiles()],
        ),
        _Group(
          title: '위험',
          children: [
            _Tile(
              icon: Icons.person_remove_outlined,
              label: '회원 삭제',
              subtitle: '서버 계정과 이 기기 저장값을 지우고 처음부터',
              isDestructive: true,
              onTap: () => widget.onSelect(_DevView.confirmReset),
            ),
          ],
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
