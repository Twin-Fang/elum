import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/logger/app_logger.dart';
import '../../../../shared/pictogram/pictogram_svg_loader.dart';

/// 사진·AI 그림이 없는 카드의 그림 자리에 그리는 **무료 픽토그램**.
///
/// Mulberry Symbols(CC BY-SA 4.0)를 앱에 번들해 두고 서버가 준 `pictogramId` 로 고른다.
/// 오프라인에서도 보이고 인증·캐시가 필요 없다.
///
/// ⚠️ **심볼을 변형하지 않는다.** 색을 바꾸거나 다른 그림과 합성하지 않고, 흰 바탕 위에
/// 크기(contain)와 배치만 정한다 — 라이선스가 변형을 막는다. 출처는 이용약관 제5조의3(그림 출처)에 있다.
class PictogramArt extends StatefulWidget {
  const PictogramArt({
    super.key,
    required this.id,
    required this.label,
    required this.fallbackBuilder,
  });

  /// 카탈로그에서 걸러진 id. 호출부가 `PictogramCatalog.parse` 를 거친 값을 넘긴다.
  final String id;

  /// 낭독기가 그림 대신 읽어 줄 이름 — 카드 제목.
  final String label;

  /// 자산을 못 읽었을 때 대신 그릴 것(기본 카드). 그림 자리가 비거나 붉은 에러로 덮이지 않게 한다.
  final WidgetBuilder fallbackBuilder;

  /// 그림 둘레 여백 — 313×230 칸에서 심볼이 테두리에 붙지 않을 만큼.
  static const _inset = 14.0;

  @override
  State<PictogramArt> createState() => _PictogramArtState();
}

class _PictogramArtState extends State<PictogramArt> {
  /// 자산을 못 읽었다. 여백 안이 아니라 **그림 자리 전체**를 기본 카드로 바꿔야 해서
  /// SvgPicture 의 errorBuilder 안에서 그리지 않고 여기서 갈아 끼운다.
  var _failed = false;

  @override
  void didUpdateWidget(PictogramArt old) {
    super.didUpdateWidget(old);
    // 다른 심볼로 바뀌면 다시 시도한다
    if (old.id != widget.id) _failed = false;
  }

  void _markFailed(Object error, StackTrace? stack) {
    // 카드 제목·설명은 보호자가 쓴 글이라 남기지 않고 id 만 남긴다 (원칙 5번)
    AppLogger.error('pictogram', error, stack, {'id': widget.id});
    // errorBuilder 는 빌드 중에 불려 여기서 setState 를 못 한다
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_failed) setState(() => _failed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return widget.fallbackBuilder(context);
    // **칸을 꽉 채운다.** 부모(AnimatedSwitcher 의 Stack)가 느슨한 제약만 줘서, 안 그러면
    // SVG 원래 크기(정사각)로 줄어 칸 가운데에 떠 버린다 (사진과 같은 사정).
    return SizedBox.expand(
      child: Semantics(
        label: widget.label,
        image: true,
        // 안쪽 SVG 가 따로 읽히지 않게 — 제목 하나만 읽는다
        excludeSemantics: true,
        child: ColoredBox(
          // 심볼은 투명 배경이라 어떤 색 위에서도 읽히지만, 시안 그림칸이 흰색이다.
          color: Colors.white,
          child: Padding(
            padding: EdgeInsets.all(PictogramArt._inset.w),
            // SvgPicture.asset 대신 전용 로더 — `<style>` 색을 풀어 주지 않으면 262개가 검게 나온다
            child: SvgPicture(
              PictogramSvgLoader(widget.id),
              key: ValueKey('pictogram-${widget.id}'),
              fit: BoxFit.contain,
              alignment: Alignment.center,
              // 파싱·로딩 실패도 앱을 죽이면 안 된다 — 기본 카드로 대체한다.
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
