import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/theme_context_ext.dart';
import '../../../credit/data/credit_repository.dart';

/// 생성 직전 크레딧 안내 — [child](하단 버튼) 위에 붙는다 (#407 스펙 §5).
///
/// 남은 양이 일과 하나의 최대 사용량(11)보다 적을 때만 나온다. 그림이 많이 붙으면
/// 이번 일과로 0 이 될 수 있다는 것을 **누르기 전에** 알린다 — 누른 뒤에 알면
/// 다음 일과를 못 만드는 것을 뒤늦게 안다.
///
/// 안 보일 때는 [child] 를 **그대로** 돌려준다. 감싸는 Column 이 끼면 크레딧 조회가
/// 실패·로딩인 화면(테스트 기본값)까지 배치가 바뀐다.
///
/// ⚠️ 시안 밖 요소다 — 디자이너 협의 대상.
class CreditLowNotice extends ConsumerWidget {
  const CreditLowNotice({super.key, required this.child});

  final Widget child;

  static const _radius = 12.0;
  static const _padH = 16.0;
  static const _padV = 12.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 조회 실패·로딩은 안내하지 않는다 — 흐름을 막지 않고 판정은 서버가 한다.
    final summary = ref.watch(creditSummaryProvider).value;
    if (summary == null || !summary.enabled || !summary.isLow) return child;

    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.creditNoticeBg,
            borderRadius: BorderRadius.circular(_radius.r),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: _padH.w, vertical: _padV.h),
            child: Text(
              '크레딧이 ${summary.available}개 남았어요. '
              '그림이 여러 장 생성돼도 이번 일과는 끝까지 만들어지고 크레딧은 0이 될 수 있어요',
              style: context.typo.creditBody.copyWith(color: colors.creditAccentText),
            ),
          ),
        ),
        SizedBox(height: context.space.sm),
        child,
      ],
    );
  }
}
