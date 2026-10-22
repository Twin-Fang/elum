import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';

/// 카드 이미지 자리.
///
/// 서버가 만든 그림을 보여주고, 없으면 [emptyBuilder]의 기본 카드로 채운다.
/// 자리를 비우면 카드 비율이 무너진다.
/// 스피커 아이콘. 읽는 중에는 민트 원(켜짐) 위로 파동이 퍼져 "지금 소리가 난다"가 한눈에 보인다.
///
/// 동작 줄이기를 켰다면 파동은 빼고 색 원만 남긴다.
class ActionCardSpeakerGlyph extends StatefulWidget {
  const ActionCardSpeakerGlyph({
    super.key,
    required this.size,
    required this.speaking,
  });

  final double size;
  final bool speaking;

  @override
  State<ActionCardSpeakerGlyph> createState() => _SpeakerGlyphState();
}

class _SpeakerGlyphState extends State<ActionCardSpeakerGlyph>
    with SingleTickerProviderStateMixin {
  // late final 로 두면 한 번도 안 쓴 채 dispose 될 때 그 자리에서 만들어져 틱커 오류가 난다
  late final AnimationController _pulse;

  @override
  void didUpdateWidget(ActionCardSpeakerGlyph old) {
    super.didUpdateWidget(old);
    if (widget.speaking == old.speaking) return;
    if (widget.speaking && !MediaQuery.disableAnimationsOf(context)) {
      _pulse.repeat();
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: AppMotion.float ~/ 2);
    // 처음 그릴 때 이미 읽는 중일 수 있다(화면이 다시 만들어진 경우)
    if (widget.speaking) _pulse.repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final speakingTint = context.colors.checkDone;
    final reduce = MediaQuery.disableAnimationsOf(context);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (widget.speaking && !reduce)
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) => Container(
                width: size * (1 + _pulse.value * 0.9),
                height: size * (1 + _pulse.value * 0.9),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: speakingTint.withValues(alpha: 0.28 * (1 - _pulse.value)),
                ),
              ),
            ),
          // 읽는 중에는 민트 원과 그림자를 깔아 눌린 채 켜져 있음을 보여 준다
          AnimatedContainer(
            duration: AppMotion.fast,
            width: size * 1.35,
            height: size * 1.35,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.speaking
                  ? speakingTint.withValues(alpha: 0.18)
                  : Colors.transparent,
              boxShadow: widget.speaking
                  ? [
                      BoxShadow(
                        color: speakingTint.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : const [],
            ),
          ),
          SizedBox(
            width: size,
            height: size,
            child: SvgPicture.asset(AppAssets.iconVolume, fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }
}
