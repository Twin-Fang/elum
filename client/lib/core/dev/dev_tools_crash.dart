part of 'dev_tools_overlay.dart';

/// 크래시 보내기 묶음 (#659): 스위치(저장, 다음 실행에도 유지), 비치명 테스트 오류, 강제 종료
/// 운영 빌드에는 개발자 도구가 없어 이 스위치도 없음 (CrashReporter.canEnable)
class _CrashReportingTiles extends StatefulWidget {
  const _CrashReportingTiles();

  @override
  State<_CrashReportingTiles> createState() => _CrashReportingTilesState();
}

class _CrashReportingTilesState extends State<_CrashReportingTiles> {
  bool _isApplying = false;
  // 마지막 동작 결과 한 줄 (스위치 실패·테스트 전송 안내)
  String? _lastResultMessage;

  @override
  Widget build(BuildContext context) {
    final isEnabled = CrashReporter.isEnabled;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 스위치가 제목과 따로 떨어져 이름 없이 읽히지 않게 한 노드로 묶는다
        MergeSemantics(
          child: ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('크래시 보내기 (Crashlytics)'),
            subtitle: Text(
              _lastResultMessage ??
                  '오류 종류·스택·에러 코드만 보냄 (메시지·입력값·사용자 식별자 없음). 앱을 꺼도 유지',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Switch(
              value: isEnabled,
              onChanged: _isApplying ? null : _onCrashReportingSwitched,
            ),
          ),
        ),
        _Tile(
          icon: Icons.report_gmailerrorred_outlined,
          label: '테스트 오류 보내기',
          subtitle: isEnabled
              ? '비치명 1건 (${CrashReporter.testErrorCode})'
              : '크래시 보내기를 먼저 켜기',
          onTap: isEnabled ? _onSendTestErrorPressed : null,
        ),
        _Tile(
          icon: Icons.dangerous_outlined,
          label: '테스트 크래시 (앱 종료)',
          subtitle: isEnabled
              ? '앱이 바로 꺼짐. 다시 켜면 보고서가 올라감'
              : '크래시 보내기를 먼저 켜기',
          isDestructive: true,
          onTap: isEnabled ? CrashReporter.sendTestCrash : null,
        ),
      ],
    );
  }

  // 스위치 저장 > 반영 > 실패면 안내 (Firebase 설정 파일 없는 빌드 등)
  Future<void> _onCrashReportingSwitched(bool isTurnedOn) async {
    setState(() => _isApplying = true);
    final isApplied = await CrashReporter.setEnabledByDeveloper(isTurnedOn);
    if (!mounted) return;
    setState(() {
      _isApplying = false;
      _lastResultMessage = isApplied ? null : '반영 실패: Firebase 설정이 없는 빌드일 수 있음 (로그 보기)';
    });
  }

  void _onSendTestErrorPressed() {
    CrashReporter.sendTestError();
    setState(() => _lastResultMessage = '테스트 오류 1건 보냄. 콘솔 반영까지 몇 분 걸림');
  }
}
