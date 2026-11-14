import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/lock_screen/lock_screen_bridge.dart';
import '../../../core/lock_screen/lock_screen_routes.dart';
import '../../../core/lock_screen/lock_screen_snapshot.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_secondary_button.dart';
import 'widgets/elumi_lock_card.dart';
import 'widgets/guardian_lock_card.dart';
import 'widgets/lock_screen_frame.dart';

/// 잠금화면 위 카드 (잠금 엔진 첫 화면): 보일 때마다 저장된 요약을 다시 읽음 > 카드 종류별 본문
/// 보호자: 오늘 진행 + 앱 열기 · 1시간 쉬기 / 이룸이: 지금 할 카드 한 장 + 시작하기
/// 앱 열기·시작하기는 잠금을 푼 뒤에만 (광고·결제는 잠금 위에 없음)
class LockScreenPage extends ConsumerStatefulWidget {
  const LockScreenPage({super.key});

  @override
  ConsumerState<LockScreenPage> createState() => _LockScreenPageState();
}

class _LockScreenPageState extends ConsumerState<LockScreenPage> {
  StreamSubscription<void>? _shownSubscription;
  LockScreenMode? _mode;
  LockScreenSnapshot? _snapshot;

  LockScreenBridge get _bridge => ref.read(lockScreenBridgeProvider);

  @override
  void initState() {
    super.initState();
    _shownSubscription = _bridge.shownSignals.listen((_) => _reload());
    unawaited(_bridge.consumePendingShow());
    unawaited(_reload());
  }

  @override
  void dispose() {
    _shownSubscription?.cancel();
    super.dispose();
  }

  /// 설정(카드 종류)·요약 다시 읽기 (실패면 null 요약 > "앱을 열어 확인")
  Future<void> _reload() async {
    final (settings, snapshot) = await (
      _bridge.getSettings(),
      _bridge.readSnapshot(),
    ).wait;
    if (!mounted) return;
    setState(() {
      _mode = settings.mode;
      _snapshot = snapshot;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mode = _mode;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_bridge.dismiss());
      },
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: SafeArea(
          child: mode == null
              ? const SizedBox.shrink()
              : LockScreenCardView(
                  mode: mode,
                  snapshot: _snapshot,
                  now: DateTime.now(),
                  onOpenApp: () =>
                      unawaited(_bridge.unlockAndOpen(LockScreenRoutes.home)),
                  onStartRoutine: (routineId) => unawaited(
                    _bridge.unlockAndOpen(LockScreenRoutes.routine(routineId)),
                  ),
                  onPauseOneHour: () => unawaited(_bridge.pauseOneHour()),
                  onClose: () => unawaited(_bridge.dismiss()),
                ),
        ),
      ),
    );
  }
}

/// 카드 종류별 본문 + 버튼 (잠금 엔진 화면과 앱 안 미리 보기가 같이 씀)
class LockScreenCardView extends StatelessWidget {
  const LockScreenCardView({
    super.key,
    required this.mode,
    required this.snapshot,
    required this.now,
    required this.onOpenApp,
    required this.onStartRoutine,
    required this.onPauseOneHour,
    required this.onClose,
  });

  final LockScreenMode mode;
  final LockScreenSnapshot? snapshot;
  final DateTime now;
  final VoidCallback onOpenApp;
  final void Function(String routineId) onStartRoutine;
  final VoidCallback onPauseOneHour;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final snapshot = this.snapshot;
    final elumiCard = snapshot != null && snapshot.isFreshOn(now)
        ? snapshot.elumiCard
        : null;
    // 이룸이 카드: 큰 그림 한 장 + 시작하기 하나 (요약이 없으면 보호자 카드의 "앱을 열어 확인" 으로)
    if (mode == LockScreenMode.elumi && elumiCard != null) {
      return LockScreenFrame(
        onClose: onClose,
        body: ElumiLockCard(card: elumiCard),
        actions: [
          ElumButton(
            label: context.l10n.lockScreenElumiStart,
            onPressed: () => onStartRoutine(elumiCard.routineId),
          ),
        ],
      );
    }
    return LockScreenFrame(
      onClose: onClose,
      body: GuardianLockCard(snapshot: snapshot, now: now),
      actions: [
        ElumButton(label: context.l10n.lockScreenOpenApp, onPressed: onOpenApp),
        if (mode == LockScreenMode.guardian)
          ElumSecondaryButton(
            label: context.l10n.lockScreenPauseOneHour,
            onTap: onPauseOneHour,
          ),
      ],
    );
  }
}
