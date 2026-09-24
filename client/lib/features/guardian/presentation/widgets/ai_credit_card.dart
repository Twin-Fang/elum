import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/network/app_failure.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../credit/data/credit_repository.dart';
import 'ai_credit_summary_view.dart';

/// 보호자 설정의 `이번 주 AI 생성` 카드 (#407 스펙 §5).
///
/// 제목 아래·첫 줄 위에 선다. 상태는 여덟이다 — 로딩 / 정상 / 보너스 / 적음 / 0 /
/// 만드는 중 / 조회 실패 / 꺼짐. 꺼져 있으면 **자리도 차지하지 않는다** — 정책을 끈
/// 운영에서 빈 카드가 남으면 무언가 고장 난 것처럼 보인다.
///
/// 구매·플랜 표시는 두지 않는다(이슈 결정) — 지금은 모두 같은 무료 크레딧이다.
class AiCreditCard extends ConsumerWidget {
  const AiCreditCard({super.key});

  static const loadingKey = ValueKey('ai-credit-loading');
  static const barKey = ValueKey('ai-credit-bar');
  static const contentKey = ValueKey('ai-credit-content');
  static const infoKey = ValueKey('ai-credit-info');

  /// 카드 아래 → 첫 설정 줄. 카드가 없으면 이 간격도 없다.
  static const _gapBelow = 16.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(creditSummaryProvider);

    final Widget? card = switch (async) {
      AsyncData(value: final s) when !s.enabled => null,
      AsyncData(value: final s) => AiCreditSummaryView(summary: s),
      AsyncError(:final error) => _ErrorBody(
        failure: AppFailure.of(error),
        onRetry: () => ref.invalidate(creditSummaryProvider),
      ),
      _ => const _LoadingBody(),
    };
    if (card == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: _gapBelow.h),
      child: AiCreditFrame(child: card),
    );
  }
}

/// 흰 카드 면. 상태가 바뀌어도 테두리·여백이 같아야 자리가 출렁이지 않는다.
class AiCreditFrame extends StatelessWidget {
  const AiCreditFrame({super.key, required this.child});

  final Widget child;

  static const _radius = 20.0;
  static const _padH = 20.0;
  static const _padV = 20.0;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.creditCardBg,
        borderRadius: BorderRadius.circular(_radius.r),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: _padH.w, vertical: _padV.h),
        child: child,
      ),
    );
  }
}

/// 불러오는 중. **숫자를 그리지 않는다** — 잠깐이라도 0 이 보이면 다 쓴 줄 안다.
class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      key: AiCreditCard.loadingKey,
      label: '이번 주 AI 생성 사용량을 불러오고 있어요',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '이번 주 AI 생성',
            style: context.typo.creditTitle.copyWith(color: colors.textPrimary),
          ),
          SizedBox(height: context.space.md),
          AiCreditBar(ratio: 0, color: colors.creditBarTrack),
        ],
      ),
    );
  }
}

/// 조회 실패 — 무엇이 안 됐는지 · 다시 하기 · 추적 코드.
class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.failure, required this.onRetry});

  final AppFailure failure;
  final VoidCallback onRetry;

  static const _chipPadH = 16.0;
  static const _chipPadV = 8.0;
  static const _chipRadius = 20.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final hint = failure.hint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 제목과 안내를 한 덩어리로 읽힌다. 다시 하기는 따로 눌러야 하니 밖에 둔다.
        MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '이번 주 AI 생성',
                style: context.typo.creditTitle.copyWith(color: colors.textPrimary),
              ),
              SizedBox(height: space.xs),
              Text(
                '사용량을 불러오지 못했어요',
                style: context.typo.creditBody.copyWith(color: colors.textPrimary),
              ),
              if (hint != null)
                Text(
                  hint,
                  style: context.typo.creditBody.copyWith(color: colors.textSecondary),
                ),
            ],
          ),
        ),
        SizedBox(height: space.sm),
        // 글꼴이 커지면 버튼과 코드가 한 줄에 안 들어간다 — 넘치지 않고 줄을 바꾼다.
        Wrap(
          spacing: space.sm,
          runSpacing: space.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppPressable(
              onTap: onRetry,
              semanticLabel: '다시 하기',
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.creditNoticeBg,
                  borderRadius: BorderRadius.circular(_chipRadius.r),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: _chipPadH.w,
                    vertical: _chipPadV.h,
                  ),
                  child: Text(
                    '다시 하기',
                    style: context.typo.creditBody.copyWith(
                      color: colors.creditAccentText,
                    ),
                  ),
                ),
              ),
            ),
            // 제보를 받았을 때 어디서 멈췄는지 가릴 유일한 단서다 (docs 예외처리 규칙).
            Text(
              failure.badgeOr('E-CREDIT'),
              style: context.typo.creditCaption.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

/// 남은 비율 막대 — 숫자와 **함께** 보인다(이슈: 막대만으로는 양을 모른다).
class AiCreditBar extends StatelessWidget {
  const AiCreditBar({super.key, required this.ratio, required this.color});

  final double ratio;
  final Color color;

  static const _height = 10.0;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular((_height / 2).h);
    return ClipRRect(
      borderRadius: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(color: context.colors.creditBarTrack),
        child: SizedBox(
          height: _height.h,
          width: double.infinity,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: ratio,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color, borderRadius: radius),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
