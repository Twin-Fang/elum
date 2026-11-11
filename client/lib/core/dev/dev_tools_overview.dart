part of 'dev_tools_overlay.dart';

/// 메뉴 맨 위 `지금 상태` 카드: 서버·계정·요금제·크레딧·화면·흉내 한눈에 + 상태·로그 복사
///
/// 복사 = 채팅(Claude) 붙여넣기용 마크다운 (토큰 가림, 최근 로그 300줄)
class _StateOverviewCard extends ConsumerStatefulWidget {
  const _StateOverviewCard({required this.currentLocation, required this.onOpenFullView});

  final String? Function() currentLocation;
  final VoidCallback onOpenFullView;

  @override
  ConsumerState<_StateOverviewCard> createState() => _StateOverviewCardState();
}

class _StateOverviewCardState extends ConsumerState<_StateOverviewCard> {
  // 앱 버전은 실행 중 안 바뀜 > 한 번만 읽음
  static final Future<String> _appVersionLabel = DevStateDump.appVersionLabel();

  bool _isBusy = false;
  String? _resultMessage;
  bool _isResultError = false;

  @override
  Widget build(BuildContext context) {
    final member = ref.watch(memberProvider).value;
    final planOverride = ref.watch(devPlanOverrideProvider);
    final credit = ref.watch(creditSummaryProvider);
    final storage = ref.watch(localStorageProvider);
    final providerSimulationLabels = _providerSimulationLabels(
      planOverride: planOverride,
      isStoreForced: ref.watch(devPlanStoreForcedProvider),
      isTeaserForced: ref.watch(devProTeaserForcedProvider),
      locale: ref.watch(devLocaleOverrideProvider),
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(color: _DevPalette.overviewBackground, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '지금 상태',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const Spacer(),
              FutureBuilder<String>(
                future: _appVersionLabel,
                builder: (context, snapshot) => Text(
                  '앱 ${snapshot.data ?? '…'}',
                  style: const TextStyle(fontSize: 12, color: _DevPalette.overviewCaption),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _OverviewLine(
            label: '서버',
            valueText: AppConfig.isProductionApiServer
                ? '운영 · ${Uri.tryParse(AppConfig.apiBaseUrl)?.host ?? ''}'
                : AppConfig.apiBaseUrl,
            isChanged: !AppConfig.isProductionApiServer,
          ),
          _OverviewLine(label: '계정', valueText: _accountLabel(member, storage)),
          _OverviewLine(
            label: '요금제',
            valueText: _planLabel(member, planOverride),
            isChanged: planOverride != DevPlanOverride.server,
          ),
          _OverviewLine(label: '크레딧', valueText: _creditLabel(credit)),
          _OverviewLine(label: '화면', valueText: _readLocation(widget.currentLocation) ?? '(모름)'),
          ListenableBuilder(
            listenable: Listenable.merge([DevSimulation.appStatus, DevSimulation.networkFault]),
            builder: (context, _) {
              final labels = [...DevSimulation.activeLabels(), ...providerSimulationLabels];
              return labels.isEmpty
                  ? const SizedBox.shrink()
                  : _OverviewLine(label: '흉내', valueText: labels.join(' · '), isChanged: true);
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _OverviewActionButton(
                  icon: Icons.content_copy,
                  label: '상태·로그 복사',
                  isPrimary: true,
                  onPressed: _isBusy ? null : _onCopyPressed,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OverviewActionButton(
                  icon: Icons.send_outlined,
                  label: '의견으로 보내기',
                  isPrimary: false,
                  onPressed: _isBusy ? null : _onSendAsFeedbackPressed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              _isBusy ? '모으는 중…' : '토큰 가림 · 최근 로그 300줄 · 보내기는 관리자 의견 목록으로',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: _DevPalette.overviewCaption),
            ),
          ),
          if (_resultMessage != null) _buildResultMessage(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: _isBusy ? null : _onExportPressed,
                child: const Text('전체 파일 내보내기', style: TextStyle(fontSize: 13, color: Colors.white)),
              ),
              const Text('·', style: TextStyle(color: _DevPalette.overviewCaption)),
              TextButton(
                onPressed: widget.onOpenFullView,
                child: const Text('전체 값 보기', style: TextStyle(fontSize: 13, color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultMessage() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(
            _isResultError ? Icons.error_outline : Icons.check_circle,
            size: 16,
            color: _isResultError ? const Color(0xFFFF6961) : _DevPalette.success,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(_resultMessage ?? '', style: const TextStyle(fontSize: 12, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 보고서 > 클립보드
  Future<void> _onCopyPressed() async {
    setState(() => _isBusy = true);
    try {
      final report = await _buildReport();
      await Clipboard.setData(ClipboardData(text: report.text));
      final size = DevStateDump.formatBytes(utf8.encode(report.text).length);
      _showResult('복사했어요 · $size · 로그 ${report.logLineCount}줄. 채팅에 붙여 넣으세요');
    } catch (error) {
      _showResult('복사하지 못했어요: $error', isError: true);
    }
  }

  // 보고서 > 의견 1건 (본문 = 한 줄 요약, 첨부 기록 = 보고서). 의견 id 를 보여 찾기 쉽게
  Future<void> _onSendAsFeedbackPressed() async {
    setState(() => _isBusy = true);
    try {
      final report = await _buildReport();
      final location = _readLocation(widget.currentLocation) ?? '(모름)';
      final attempt = await ref
          .read(feedbackRepositoryProvider)
          .send(
            message: '[개발자 도구 상태 보고] $location · ${DevStateReport.formatLocalTime(DateTime.now())}',
            appLog: report.text,
            appVersion: await DevStateDump.appVersionLabel(),
            os: '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
          );
      final feedbackId = attempt.value;
      if (feedbackId == null) {
        final failure = attempt.failure;
        _showResult('보내지 못했어요: ${failure == null ? '알 수 없음' : _describeFailure(failure)}', isError: true);
        return;
      }
      final shortId = feedbackId.length > 8 ? feedbackId.substring(0, 8) : feedbackId;
      _showResult('보냈어요 · 의견 $shortId (로그 ${report.logLineCount}줄). Claude 에게 "의견 $shortId 봐줘"');
    } catch (error) {
      _showResult('보내지 못했어요: $error', isError: true);
    }
  }

  // 크레딧 응답 대기(최대 3초) > 칸 모으기(토큰 가림) > 보고서 (복사·보내기 공통)
  Future<DevClipboardReport> _buildReport() async {
    try {
      await ref.read(creditSummaryProvider.future).timeout(const Duration(seconds: 3));
    } catch (_) {
      // 크레딧을 못 받아도 진행 (그 칸에 사유가 들어감)
    }
    final sections = await DevStateDump.collect(
      context: mounted ? context : null,
      liveSections: _readLiveSections(ref, widget.currentLocation),
      shouldRevealTokens: false,
    );
    return DevStateReport.build(sections);
  }

  Future<void> _onExportPressed() async {
    setState(() => _isBusy = true);
    final message = await _exportFullDump(context, ref, widget.currentLocation);
    _showResult(message.$1, isError: message.$2);
  }

  void _showResult(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _isBusy = false;
      _resultMessage = message;
      _isResultError = isError;
    });
  }
}

/// 카드 한 줄: 이름(회색) + 값 (바뀐 값은 주황)
class _OverviewLine extends StatelessWidget {
  const _OverviewLine({required this.label, required this.valueText, this.isChanged = false});

  final String label;
  final String valueText;
  final bool isChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(label, style: const TextStyle(fontSize: 13, color: _DevPalette.overviewCaption)),
          ),
          Expanded(
            child: Text(
              valueText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isChanged ? const Color(0xFFFFA94D) : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
