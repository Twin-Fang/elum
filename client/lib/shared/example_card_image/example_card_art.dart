import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/assets/app_assets.dart';
import '../../core/logger/app_logger.dart';

/// 사진·AI 그림이 없는 예시 일과 카드의 그림 자리에 그리는 번들 이미지 (루미, 투명 배경 WebP).
///
/// 서버가 준 `exampleImageId` 로 고른다. 오프라인에서도 보이고 인증·캐시가 필요 없다.
/// 흰 바탕 위에 크기(contain)와 배치만 정한다 — [PictogramArt] 와 같은 칸 규칙.
class ExampleCardArt extends StatefulWidget {
  const ExampleCardArt({
    super.key,
    required this.id,
    required this.label,
    required this.fallbackBuilder,
  });

  /// `ExampleCardImageCatalog.parse` 를 거친 id.
  final String id;

  /// 낭독기가 그림 대신 읽어 줄 이름 — 카드 제목.
  final String label;

  /// 자산을 못 읽었을 때 대신 그릴 것. 그림 자리가 비거나 붉은 에러로 덮이지 않게 한다.
  final WidgetBuilder fallbackBuilder;

  /// 그림 둘레 여백 — 313×230 칸에서 루미가 테두리에 붙지 않을 만큼.
  static const _inset = 8.0;

  @override
  State<ExampleCardArt> createState() => _ExampleCardArtState();
}

class _ExampleCardArtState extends State<ExampleCardArt> {
  /// 자산을 못 읽었다. 그림 자리 전체를 대체 그림으로 갈아 끼운다.
  var _failed = false;

  @override
  void didUpdateWidget(ExampleCardArt old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) _failed = false;
  }

  void _markFailed(Object error, StackTrace? stack) {
    // 카드 제목은 보호자가 쓴 글일 수 있어 id 만 남긴다 (원칙 5번)
    AppLogger.error('example card art', error, stack, {'id': widget.id});
    // errorBuilder 는 빌드 중에 불려 여기서 setState 를 못 한다
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_failed) setState(() => _failed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return widget.fallbackBuilder(context);
    // 칸을 꽉 채운다 — 부모 Stack 이 느슨한 제약만 줘서 expand 없이는 정사각으로 줄어 가운데에 뜬다
    return SizedBox.expand(
      child: Semantics(
        label: widget.label,
        image: true,
        excludeSemantics: true,
        child: ColoredBox(
          color: Colors.white,
          child: Padding(
            padding: EdgeInsets.all(ExampleCardArt._inset.w),
            child: Image.asset(
              AppAssets.exampleRoutineImage(widget.id),
              key: ValueKey('example-card-${widget.id}'),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) {
                _markFailed(error, stack);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
  }
}
