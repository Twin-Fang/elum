import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/theme_context_ext.dart';
import 'library_routine_tile.dart';

/// 손가락을 따라다니는 칸: 제자리 칸과 같은 모양을 키우고 그림 아래 그림자를 깐다
///
/// [lift] 0~1: 집은 정도 (크기 · 그림자). [opacity] 는 묶음에 빨려 들어갈 때 줄인다.
/// [anchor] 를 기준점으로 키워 집은 지점이 손가락 밑에 남는다.
class LibraryGridLiftedTile extends StatelessWidget {
  const LibraryGridLiftedTile({
    super.key,
    required this.rect,
    required this.anchor,
    required this.scale,
    required this.lift,
    required this.opacity,
    required this.child,
  });

  /// 칸이 놓일 상자 (격자 내용 좌표, 키우기 전)
  final Rect rect;
  final Alignment anchor;
  final double scale;
  final double lift;
  final double opacity;
  final Widget child;

  /// 다 집었을 때 그림자 번짐 · 짙기
  static const _shadowBlur = 18.0;
  static const _shadowAlpha = 0.28;

  @override
  Widget build(BuildContext context) {
    final iconSize = LibraryRoutineTile.iconSize.w;
    final radius = BorderRadius.circular(LibraryRoutineTile.iconRadius.w);
    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale,
            alignment: anchor,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                // 그림 칸 바로 아래 그림자 (이름 글자에는 깔지 않는다)
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.textPrimary.withValues(
                          alpha: _shadowAlpha * lift,
                        ),
                        blurRadius: _shadowBlur * lift,
                        offset: Offset(0, 4.h * lift),
                      ),
                    ],
                  ),
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
