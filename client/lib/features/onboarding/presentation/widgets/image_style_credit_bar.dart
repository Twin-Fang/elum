import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../credit/application/credit_costs.dart';
import '../../domain/image_style.dart';

/// 그림 방식 목록 위의 크레딧 띠 — 고른 방식이 크레딧을 얼마나 쓰는지 보인다.
///
/// 기본 그림은 `일과 1개`, 만화·실사는 `일과 1개 + 그림 한 장 1개`. 카드와 같은 흰 띠라
/// 목록과 한 덩어리로 읽히고, 방식을 바꿔도 높이가 그대로라 아래 카드가 움직이지 않는다.
/// 시안에 없는 임시 모양이다.
///
/// 숫자는 서버 단가를 쓴다 — 관리자가 단가를 바꾸면 따라간다. 못 받으면 기본 단가(1)다.
/// 크레딧 기능이 꺼져 있으면 쓸 일이 없으니 띠를 감춘다.
class ImageStyleCreditBar extends ConsumerWidget {
  const ImageStyleCreditBar({super.key, required this.style});

  final ImageStyle style;

  static const _coinSize = 22.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final costs = ref.watch(creditCostsProvider);
    if (costs == null) return const SizedBox.shrink();

    final colors = context.colors;
    final typo = context.typo;
    final l10n = context.l10n;
    final routineCost = costs.routine;
    final imageCost = costs.image;

    final routine = l10n.imageStyleCreditRoutine(routineCost);
    final image = l10n.imageStyleCreditImage(imageCost);
    final label = l10n.imageStyleCreditLabel;

    return Semantics(
      container: true,
      label: [label, routine, if (style.drawsCardImages) image].join(', '),
      child: ExcludeSemantics(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Row(
            children: [
              const _Coin(size: _coinSize),
              SizedBox(width: 10.w),
              Text(
                label,
                style: typo.imageStyleCreditBar.copyWith(
                  color: colors.brandOrange,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(width: 12.w),
              // 글자를 키우면 항목이 다음 줄로 꺾인다 (넘침 방지)
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6.w,
                  runSpacing: 4.h,
                  children: [
                    _Cost(text: routine, count: routineCost),
                    if (style.drawsCardImages) ...[
                      Text(
                        '+',
                        style: typo.imageStyleCreditBar.copyWith(
                          color: colors.routineTileLabel,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      _Cost(text: image, count: imageCost),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `일과 1개` — 숫자와 단위(`1개`)만 주황으로 칠한다.
///
/// 문구는 언어마다 어순이 달라 통째로 받고, 숫자가 처음 나오는 자리부터 끝까지를 강조한다.
/// 숫자가 없으면 전부 기본색이다.
class _Cost extends StatelessWidget {
  const _Cost({required this.text, required this.count});

  final String text;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final base = context.typo.imageStyleCreditBar.copyWith(
      color: colors.textPrimary,
    );
    final at = text.indexOf('$count');
    if (at < 0) return Text(text, style: base);

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text.substring(0, at), style: base),
          TextSpan(
            text: text.substring(at),
            style: base.copyWith(
              color: colors.brandOrange,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// 크레딧 동전 — 주황 원 안에 흰 반짝임.
class _Coin extends StatelessWidget {
  const _Coin({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final side = size.w;
    return Container(
      width: side,
      height: side,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.colors.brandOrange,
        shape: BoxShape.circle,
      ),
      child: SvgPicture.asset(
        AppAssets.iconSparkles,
        width: side * 0.6,
        height: side * 0.6,
        colorFilter: ColorFilter.mode(context.colors.surface, BlendMode.srcIn),
        excludeFromSemantics: true,
      ),
    );
  }
}
