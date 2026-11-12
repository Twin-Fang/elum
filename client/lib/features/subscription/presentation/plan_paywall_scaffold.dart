import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/min_tap_target.dart';
import '../application/plan_purchase_notifier.dart';

/// 요금제 화면 틀 (폰 시트 · 태블릿 카드 공통): 스크롤 내용 + 오른쪽 위 ✕ + (있으면) 바닥에 고정한 결제 버튼
///
/// 결제 진행 중에는 ✕·뒤로가기·바깥 누르기로 닫지 않음. 버튼이 늘 보여 큰 글자에서도 결제·닫기 길이 남음 (#1167)
/// 스크롤되면 위쪽에 배경색 띠를 깔아 내용이 손잡이·✕ 밑으로 흐려지며 사라지게 함 (#1265)
class PlanPaywallScaffold extends ConsumerStatefulWidget {
  const PlanPaywallScaffold({super.key, required this.content, this.footer});

  /// 스크롤되는 내용 (맨 위는 ✕ 자리를 비워 둠)
  final Widget content;

  /// 바닥 고정 (결제 버튼 + 한 줄). null 이면 없음 (결제 단계 안내)
  final Widget? footer;

  /// ✕: 위 12 · 오른쪽 12 · 원 32 · 아이콘 16
  static const _closeInset = 12.0;
  static const _closeSize = 32.0;
  static const _closeIconSize = 16.0;

  @override
  ConsumerState<PlanPaywallScaffold> createState() => _PlanPaywallScaffoldState();
}

class _PlanPaywallScaffoldState extends ConsumerState<PlanPaywallScaffold> {
  /// 위쪽 띠 높이: ✕ 아래 끝(12 + 32) + 흐려지는 구간 16
  static const _topFadeHeight = 60.0;
  static const _topFadeDuration = Duration(milliseconds: 150);

  /// 내용이 맨 위에서 내려갔는가 (맨 위면 머리 그림 배경을 가리지 않게 띠를 숨김)
  bool _isScrolled = false;

  bool _onScroll(ScrollNotification notification) {
    final isScrolled = notification.metrics.pixels > 0;
    if (isScrolled != _isScrolled) setState(() => _isScrolled = isScrolled);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = ref.watch(planPurchaseStateProvider.select((state) => state.isBusy));
    final footer = widget.footer;
    final background = context.colors.background;
    return PopScope(
      canPop: !isBusy,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: Stack(
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: _onScroll,
                  child: SingleChildScrollView(child: widget.content),
                ),
                // 위쪽 띠 (배경색 > 투명, 누르기는 통과)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _isScrolled ? 1 : 0,
                      duration: _topFadeDuration,
                      child: Container(
                        height: _topFadeHeight.h,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [background, background, background.withValues(alpha: 0)],
                            stops: const [0, 0.7, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: PlanPaywallScaffold._closeInset.h,
                  right: PlanPaywallScaffold._closeInset.w,
                  child: _closeButton(context, isEnabled: !isBusy),
                ),
              ],
            ),
          ),
          ?footer,
        ],
      ),
    );
  }

  Widget _closeButton(BuildContext context, {required bool isEnabled}) {
    final colors = context.colors;
    return Semantics(
      button: true,
      enabled: isEnabled,
      label: context.l10n.commonClose,
      child: AppPressable(
        onTap: isEnabled ? Navigator.of(context).pop : null,
        child: MinTapTarget(
          child: Container(
            width: PlanPaywallScaffold._closeSize.w,
            height: PlanPaywallScaffold._closeSize.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: colors.proPlanCloseFill, shape: BoxShape.circle),
            child: SvgPicture.asset(
              AppAssets.iconClose,
              width: PlanPaywallScaffold._closeIconSize.w,
              height: PlanPaywallScaffold._closeIconSize.w,
              colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }
}
