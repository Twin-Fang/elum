import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/theme_context_ext.dart';
import '../../domain/talk_post.dart';
import 'talk_step_image.dart';

/// 피드 카드 그림 칸 하나: 반지름 12 + 1px 테두리 (시안 1783:6667)
/// [step] 이 없으면 테두리만 있는 흰 칸 (카드가 4장보다 적을 때)
/// 크기는 부모가 정한다
class TalkStepTile extends StatelessWidget {
  const TalkStepTile({
    super.key,
    required this.postId,
    required this.step,
    this.overlay,
  });

  final String postId;
  final TalkStep? step;

  /// 그림 위에 겹칠 것 (최신 글 카드 마지막 칸의 `+N`)
  final Widget? overlay;

  static const _radius = 12.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final step = this.step;
    final overlay = this.overlay;
    final radius = BorderRadius.circular(_radius.r);
    return Container(
      // 테두리는 그림 위에 그려야 사진 가장자리에 묻히지 않는다
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: colors.talkCardBorder),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: step == null
            ? ColoredBox(color: colors.surface, child: const SizedBox.expand())
            : Stack(
                fit: StackFit.expand,
                children: [
                  TalkStepImage(postId: postId, step: step),
                  ?overlay,
                ],
              ),
      ),
    );
  }
}
