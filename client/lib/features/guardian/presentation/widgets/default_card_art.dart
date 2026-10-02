import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/text/keep_words.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';

/// 그림이 없는 카드의 **기본 카드** (이슈 #458).
///
/// 예전에는 그림을 못 받으면 프로필과 상관없이 고양이가 고정으로 나왔다. "옷 입기"
/// 카드에 고양이가 나오면 카드가 무엇을 하라는 것인지 흐려진다 — 그림이 없으면
/// 없는 대로 보여준다. 만화 방식에서도 그림 생성이 실패하면 같은 카드가 나온다.
///
/// ⚠️ **임시 시안이다** (디자이너 확정 전 제시용 — 목업: 대안 3-A). 확정되면 이 파일의
/// 모양만 바뀐다. 두 화면이 따로 그린다.
/// - 보호자: [DefaultCardPhotoSlot] — 점선 자리 + `사진 추가`
/// - 이룸이: [DefaultCardTitleArt] — 번호색 배경에 제목을 아주 크게
class DefaultCardPhotoSlot extends StatelessWidget {
  const DefaultCardPhotoSlot({super.key, this.onAddPhoto});

  /// `사진 추가`를 눌렀을 때. **null 이면 누를 수 없다** — 사진 바꾸기(#456)가
  /// 이 훅에 연결하기 전에는 눌러도 아무 일이 없어야 하고, 낭독기에도 버튼으로
  /// 잡히지 않아야 한다.
  final VoidCallback? onAddPhoto;

  static const _inset = 6.0;
  static const _iconSize = 32.0;
  static const _dashStroke = 2.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;

    final slot = Padding(
      padding: EdgeInsets.all(_inset.w),
      child: CustomPaint(
        // 점선은 형태 있는 일러스트가 아니라 테두리다 (client/CLAUDE.md §2 허용 범위).
        painter: _DashedBorderPainter(
          color: colors.cardPhotoSlotDash,
          radius: space.xs,
          strokeWidth: _dashStroke.w,
        ),
        child: Center(
          // 글자를 키우면 자리(약 190)를 넘길 수 있어 줄여서 담는다 — 넘쳐 잘리는 것보다 낫다.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.photo_camera_outlined,
                  size: _iconSize.w,
                  color: colors.textSecondary,
                ),
                SizedBox(height: space.xs.h),
                Text(
                  context.l10n.cardAddPhoto,
                  style: context.typo.body.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final tap = onAddPhoto;
    if (tap == null) {
      // 눌리지 않는 자리다. 낭독기가 "사진 추가"를 버튼처럼 읽으면 눌러도 아무 일이
      // 없어 고장으로 들린다.
      return ExcludeSemantics(child: slot);
    }
    return AppPressable(
      onTap: tap,
      scaleDown: AppPressable.scaleCard,
      semanticLabel: context.l10n.cardAddPhoto,
      child: slot,
    );
  }
}

/// 이룸이 화면의 기본 카드 — 글자가 그림 노릇을 한다.
///
/// 이룸이는 글자를 못 읽을 수 있다(원칙 ③ "그림이 먼저")는 것과 부딪히는 임시
/// 선택이다. 그림이 없을 때 보여줄 것이 제목뿐이라 **아주 크게** 둔다. 디자이너에게
/// 큰 글자·픽토그램 중 무엇이 나은지 묻고 있다 (design-brief 질문 1).
class DefaultCardTitleArt extends StatelessWidget {
  const DefaultCardTitleArt({super.key, required this.title, required this.color});

  final String title;

  /// 번호 배지·테두리와 같은 카드 색(`CardPalette.border`) — 카드 한 장이 한 색으로 읽힌다.
  final Color color;

  static const _pad = 16.0;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: LayoutBuilder(
        builder: (context, constraints) => Padding(
          padding: EdgeInsets.all(_pad.w),
          child: Center(
            // 제목은 자르지 않는다(무엇을 하라는 문장이다). 칸 폭에서 줄바꿈하고, 그래도
            // 칸 높이를 넘기면(긴 제목·큰 글자) 통째로 줄여서 담는다.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: (constraints.maxWidth - _pad.w * 2).clamp(
                    0.0,
                    double.infinity,
                  ),
                ),
                child: Text(
                  // 큰 글자에서 `입/어요`처럼 어절이 갈라지지 않게 띄어쓰기에서만 줄바꿈한다.
                  // 낭독기에는 원문을 준다.
                  keepWords(
                    title,
                    // 카드 글은 일과 언어를 따른다(ContentLocale 이 입힌 값). 화면 언어가 아니다.
                    locale: DefaultTextStyle.of(context).style.locale,
                  ),
                  semanticsLabel: title,
                  textAlign: TextAlign.center,
                  style: context.typo.defaultCardTitle.copyWith(
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 점선 둥근 사각형 테두리.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double strokeWidth;

  static const _dash = 8.0;
  static const _gap = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    // 선 두께의 절반만큼 안쪽으로 그려 가장자리에서 잘리지 않게 한다
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final path = Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += _dash + _gap) {
        canvas.drawPath(metric.extractPath(d, d + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius || old.strokeWidth != strokeWidth;
}
