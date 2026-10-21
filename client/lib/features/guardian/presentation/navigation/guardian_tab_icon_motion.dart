import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_motion.dart';
import 'guardian_tab.dart';

/// 칸 아이콘 고름 동작 한 장면: 아이콘 SVG 한 장을 부위별로 잘라 [progress] 시점 모양으로 그림
///
/// 부위는 사본 SVG 없이 같은 원본을 영역만 잘라 쓴다. [progress] 1 은 모든 부위가 제자리.
class GuardianTabIconMotion extends StatelessWidget {
  const GuardianTabIconMotion({
    super.key,
    required this.tab,
    required this.size,
    required this.color,
    required this.progress,
  });

  final GuardianTab tab;

  /// 정사각형 칸 한 변 (화면 배율을 이미 곱한 값)
  final double size;
  final Color color;

  /// 고름 동작 진행 0 > 1 ([AppMotion.tabIconSelect] 한 번 기준)
  final double progress;

  @override
  Widget build(BuildContext context) {
    final mapping = _ViewBoxMapping(viewBox: _viewBoxOf(tab), boxSize: size);
    return SizedBox.square(
      dimension: size,
      child: switch (tab) {
        GuardianTab.home => _buildHome(mapping),
        GuardianTab.manage => _buildManage(mapping),
        GuardianTab.talk => _buildTalk(mapping),
        GuardianTab.me => _buildMe(mapping),
      },
    );
  }

  /// SVG viewBox 크기 (assets/icon/nav/*.svg 와 같게)
  static Size _viewBoxOf(GuardianTab tab) => switch (tab) {
    GuardianTab.home => const Size(24, 24),
    GuardianTab.manage => const Size(24, 22),
    GuardianTab.talk => const Size(24, 24),
    GuardianTab.me => const Size(16, 24),
  };

  /// 홈: 찌그러짐 > 튀어 오름 > 착지하며 찌그러짐 > 제자리 (바닥 기준)
  Widget _buildHome(_ViewBoxMapping mapping) {
    return Transform.translate(
      offset: Offset(0, _homeLift.valueAt(progress) * mapping.unit),
      child: Transform.scale(
        alignment: Alignment.bottomCenter,
        scaleX: _homeScaleX.valueAt(progress),
        scaleY: _homeScaleY.valueAt(progress),
        child: _layer(tab.iconAsset),
      ),
    );
  }

  /// 일과 관리: 폴더 톡 커짐 > 안쪽 체크가 왼쪽부터 그려짐 > 머묾 > 흐려지며 사라짐
  Widget _buildManage(_ViewBoxMapping mapping) {
    final checkOpacity = _checkOpacity.valueAt(progress);
    final checkRevealRight =
        _checkLeft + (_checkRight - _checkLeft) * _checkReveal.valueAt(progress);
    return Transform.scale(
      alignment: _folderPopAlignment,
      scale: _folderPop.valueAt(progress),
      child: Stack(
        children: [
          _layer(tab.iconAsset),
          if (checkOpacity > 0)
            _layer(
              AppAssets.navFolderCheck,
              color: color.withValues(alpha: color.a * checkOpacity),
              clipper: _ViewBoxRegionClipper(
                mapping,
                Rect.fromLTRB(_checkLeft, 0, checkRevealRight, 22),
              ),
            ),
        ],
      ),
    );
  }

  /// 이야기: 말풍선이 잦아들며 흔들림 + 안쪽 글줄 두 개가 차례로 써짐
  Widget _buildTalk(_ViewBoxMapping mapping) {
    return Transform.rotate(
      alignment: mapping.alignmentOf(const Offset(12, 24)),
      angle: _bubbleSwingDegrees.valueAt(progress) * math.pi / 180,
      child: Stack(
        children: [
          _layer(
            tab.iconAsset,
            clipper: _ViewBoxRegionClipper(
              mapping,
              _talkWholeRegion,
              exclude: _talkLinesRegion,
            ),
          ),
          _talkLine(mapping, _talkTopLineRegion, _talkTopLineWrite),
          _talkLine(mapping, _talkBottomLineRegion, _talkBottomLineWrite),
        ],
      ),
    );
  }

  /// 글줄 하나: 왼쪽 끝을 기준으로 가로로 늘어남
  Widget _talkLine(_ViewBoxMapping mapping, Rect region, _Track write) {
    return Transform.scale(
      alignment: mapping.alignmentOf(region.centerLeft),
      scaleX: write.valueAt(progress),
      child: _layer(
        tab.iconAsset,
        clipper: _ViewBoxRegionClipper(mapping, region),
      ),
    );
  }

  /// 내 정보: 머리가 쏙 올라왔다 내려옴 + 몸이 눌렸다 펴짐 (발 기준)
  Widget _buildMe(_ViewBoxMapping mapping) {
    return Stack(
      children: [
        Transform.scale(
          alignment: mapping.alignmentOf(const Offset(8, 24)),
          scaleX: _bodyScaleX.valueAt(progress),
          scaleY: _bodyScaleY.valueAt(progress),
          child: _layer(
            tab.iconAsset,
            clipper: _ViewBoxRegionClipper(mapping, _meBodyRegion),
          ),
        ),
        Transform.translate(
          offset: Offset(0, _headLift.valueAt(progress) * mapping.unit),
          child: _layer(
            tab.iconAsset,
            clipper: _ViewBoxRegionClipper(mapping, _meHeadRegion),
          ),
        ),
      ],
    );
  }

  /// 아이콘 한 겹 (칸 전체 크기, 필요하면 영역만 잘라냄)
  Widget _layer(
    String asset, {
    Color? color,
    CustomClipper<Path>? clipper,
  }) {
    final picture = SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color ?? this.color, BlendMode.srcIn),
    );
    if (clipper == null) return picture;
    return ClipPath(clipper: clipper, child: picture);
  }

  // --- 시간표 (구간은 전체 1초 대비 비율, 값의 위치·거리는 viewBox 단위) ---

  // 홈 (0 ~ 0.56)
  static const _homeLift = _Track(0, .56, [
    (0, 0), (.14, 1), (.42, -7), (.66, 0), (1, 0),
  ]);
  static const _homeScaleX = _Track(0, .56, [
    (0, 1), (.14, 1.14), (.42, .94), (.66, 1.1), (.84, .97), (1, 1),
  ]);
  static const _homeScaleY = _Track(0, .56, [
    (0, 1), (.14, .82), (.42, 1.1), (.66, .88), (.84, 1.03), (1, 1),
  ]);

  // 일과 관리: 폴더 톡 (0 ~ 0.46) · 체크 (0.12 ~ 1, 0.3 까지 그림 > 0.75 까지 머묾 > 사라짐)
  static const _folderPopAlignment = Alignment(0, .2);
  static const _folderPop = _Track(0, .46, [
    (0, 1), (.3, 1.14), (.55, .96), (1, 1),
  ]);
  static const _checkReveal = _Track(.12, 1, [
    (0, 0), (.3, 1), (1, 1),
  ], curve: AppMotion.entry);
  static const _checkOpacity = _Track(.12, 1, [
    (0, 1), (.75, 1), (1, 0),
  ], curve: AppMotion.entry);

  /// 체크가 드러나는 가로 범위 (선 두께 포함, nav_folder_check.svg)
  static const _checkLeft = 6.5;
  static const _checkRight = 17.5;

  // 이야기: 말풍선 흔들 (0 ~ 0.6) · 윗줄 (0.14 ~ 0.36) · 아랫줄 (0.25 ~ 0.51)
  static const _bubbleSwingDegrees = _Track(0, .6, [
    (0, 0), (.2, -12), (.42, 9), (.62, -5), (.8, 2), (1, 0),
  ]);
  static const _talkTopLineWrite = _Track(.14, .36, [
    (0, 0), (1, 1),
  ], curve: AppMotion.decelerate);
  static const _talkBottomLineWrite = _Track(.25, .51, [
    (0, 0), (1, 1),
  ], curve: AppMotion.decelerate);

  /// 말풍선 테두리와 글줄을 가르는 영역 (nav_comment.svg — 테두리 안쪽 빈 곳에 글줄 두 개만 있음)
  static const _talkWholeRegion = Rect.fromLTRB(-2, -2, 26, 26);
  static const _talkLinesRegion = Rect.fromLTRB(7.5, 7.5, 18.5, 16.5);
  static const _talkTopLineRegion = Rect.fromLTRB(7.5, 7.5, 14.5, 11.5);
  static const _talkBottomLineRegion = Rect.fromLTRB(7.5, 12.5, 18.5, 16.5);

  // 내 정보: 머리 (0.04 ~ 0.66) · 몸 (0 ~ 0.52)
  static const _headLift = _Track(.04, .66, [
    (0, 0), (.3, -4.5), (.55, .8), (.76, -1.4), (1, 0),
  ]);
  static const _bodyScaleX = _Track(0, .52, [
    (0, 1), (.3, 1.05), (.58, 1), (1, 1),
  ]);
  static const _bodyScaleY = _Track(0, .52, [
    (0, 1), (.3, .9), (.58, 1.04), (1, 1),
  ]);

  /// 머리 · 몸 영역 (nav_user.svg — 머리 y 0~12, 몸 y 14~24)
  static const _meHeadRegion = Rect.fromLTRB(-2, -2, 18, 12.8);
  static const _meBodyRegion = Rect.fromLTRB(-2, 13.2, 18, 26);
}

/// 시간표 한 줄: [start]~[end] 구간에 [curve]를 입히고 (구간 안 비율, 값) 사이를 고르게 지나감
///
/// 구간 앞은 첫 값, 뒤는 끝 값
class _Track {
  const _Track(
    this.start,
    this.end,
    this.keyframes, {
    this.curve = AppMotion.standard,
  });

  final double start;
  final double end;
  final List<(double, double)> keyframes;
  final Curve curve;

  double valueAt(double progress) {
    final local = ((progress - start) / (end - start)).clamp(0.0, 1.0);
    final eased = curve.transform(local);
    for (var index = 1; index < keyframes.length; index++) {
      final (offset, value) = keyframes[index];
      if (eased > offset) continue;
      final (previousOffset, previousValue) = keyframes[index - 1];
      final span = offset - previousOffset;
      final fraction = span <= 0 ? 1.0 : (eased - previousOffset) / span;
      return previousValue + (value - previousValue) * fraction;
    }
    return keyframes.last.$2;
  }
}

/// viewBox 좌표 > 정사각형 칸 좌표 (SvgPicture 기본 contain · 가운데 정렬과 같게)
class _ViewBoxMapping {
  _ViewBoxMapping({required this.viewBox, required this.boxSize})
    : unit = boxSize / math.max(viewBox.width, viewBox.height);

  final Size viewBox;
  final double boxSize;

  /// viewBox 1 단위 = 칸 위 논리 픽셀
  final double unit;

  Offset get _origin => Offset(
    (boxSize - viewBox.width * unit) / 2,
    (boxSize - viewBox.height * unit) / 2,
  );

  Offset toBox(Offset point) => _origin + point * unit;

  Rect toBoxRect(Rect rect) =>
      Rect.fromPoints(toBox(rect.topLeft), toBox(rect.bottomRight));

  /// viewBox 한 점 > 칸 기준 Alignment (변형 중심용)
  Alignment alignmentOf(Offset point) {
    final inBox = toBox(point);
    return Alignment(inBox.dx / boxSize * 2 - 1, inBox.dy / boxSize * 2 - 1);
  }
}

/// viewBox 영역만 남기는 자르기 (exclude 가 있으면 그 안쪽은 뺌)
class _ViewBoxRegionClipper extends CustomClipper<Path> {
  _ViewBoxRegionClipper(this.mapping, this.include, {this.exclude});

  final _ViewBoxMapping mapping;
  final Rect include;
  final Rect? exclude;

  @override
  Path getClip(Size size) {
    final path = Path()..addRect(mapping.toBoxRect(include));
    final excludeRect = exclude;
    if (excludeRect == null) return path;
    return path
      ..fillType = PathFillType.evenOdd
      ..addRect(mapping.toBoxRect(excludeRect));
  }

  @override
  bool shouldReclip(_ViewBoxRegionClipper oldClipper) =>
      oldClipper.include != include ||
      oldClipper.exclude != exclude ||
      oldClipper.mapping.boxSize != mapping.boxSize;
}
