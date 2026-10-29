part of 'dev_tools_overlay.dart';

/// 분석 보내기 묶음 (#650): 스위치(저장, 다음 실행에도 유지), 테스트 이벤트
/// 운영 빌드에는 개발자 도구가 없어 이 스위치도 없음 (AppAnalytics.canEnable)
class _AnalyticsTiles extends StatefulWidget {
  const _AnalyticsTiles();

  @override
  State<_AnalyticsTiles> createState() => _AnalyticsTilesState();
}

class _AnalyticsTilesState extends State<_AnalyticsTiles> {
  bool _isApplying = false;
  // 마지막 동작 결과 한 줄 (스위치 실패·테스트 전송 안내)
  String? _lastResultMessage;

  @override
  Widget build(BuildContext context) {
    final isEnabled = AppAnalytics.isEnabled;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SwitchTile(
          icon: Icons.insights_outlined,
          label: '분석 보내기 (Analytics)',
          subtitle: _lastResultMessage ??
              '화면 경로·핵심 이벤트·숫자·에러 코드만 보냄 (원문·이름·사용자 id·광고 식별자 없음). 앱을 꺼도 유지',
          isOn: isEnabled,
          onChanged: _isApplying ? null : _onAnalyticsSwitched,
        ),
        _Tile(
          icon: Icons.send_outlined,
          label: '테스트 이벤트 보내기',
          subtitle: isEnabled
              ? '${AnalyticsEvents.developerTest} 1건'
              : '분석 보내기를 먼저 켜기',
          onTap: isEnabled ? _onSendTestEventPressed : null,
        ),
      ],
    );
  }

  // 스위치 저장 > 반영 > 실패면 안내 (Firebase 설정 파일 없는 빌드 등)
  Future<void> _onAnalyticsSwitched(bool isTurnedOn) async {
    setState(() => _isApplying = true);
    final isApplied = await AppAnalytics.setEnabledByDeveloper(isTurnedOn);
    if (!mounted) return;
    setState(() {
      _isApplying = false;
      _lastResultMessage = isApplied ? null : '반영 실패: Firebase 설정이 없는 빌드일 수 있음 (로그 보기)';
    });
  }

  void _onSendTestEventPressed() {
    AppAnalytics.sendTestEvent();
    setState(() => _lastResultMessage = '테스트 이벤트 1건 보냄. 콘솔 반영까지 최대 하루 (DebugView 는 바로)');
  }
}
