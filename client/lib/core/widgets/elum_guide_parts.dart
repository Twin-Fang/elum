import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../l10n/l10n_context.dart';
import '../text/keep_words.dart';
import '../theme/theme_context_ext.dart';

// 안내 창·시트 내용 줄 부품: 아이콘 타일 · 표 줄 · 설명 줄 · 항목 줄 · 구분선 (뼈대는 elum_guide_panel.dart)

/// 줄 머리 아이콘 타일: 둥근 타일(32, 모서리 10) 위 선 아이콘 16 (홈 안내 카드 타일과 같은 바탕색)
class ElumGuideIconTile extends StatelessWidget {
  const ElumGuideIconTile({super.key, required this.iconAsset});

  /// AppAssets 의 icon* SVG
  final String iconAsset;

  static const _tileSize = 32.0;
  static const _tileRadius = 10.0;
  static const _iconSize = 16.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: _tileSize.w,
      height: _tileSize.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: colors.proPlanTileExtra, borderRadius: BorderRadius.circular(_tileRadius.r)),
      child: SvgPicture.asset(
        iconAsset,
        width: _iconSize.w,
        height: _iconSize.w,
        excludeFromSemantics: true,
        colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
      ),
    );
  }
}

/// 칸 머리 그림 타일: 둥근 타일(44, 모서리 12) 위 PNG 그림, 안쪽 여백 4 (홈 안내 카드 타일과 같은 모양)
class ElumGuidePictureTile extends StatelessWidget {
  const ElumGuidePictureTile({super.key, required this.asset});

  /// AppAssets 의 PNG 그림
  final String asset;

  static const _tileSize = 44.0;
  static const _tileRadius = 12.0;
  static const _tilePadding = 4.0;

  @override
  Widget build(BuildContext context) => Container(
    width: _tileSize.w,
    height: _tileSize.w,
    padding: EdgeInsets.all(_tilePadding.w),
    decoration: BoxDecoration(
      color: context.colors.proPlanTileExtra,
      borderRadius: BorderRadius.circular(_tileRadius.r),
    ),
    child: Image.asset(asset, fit: BoxFit.contain, excludeFromSemantics: true),
  );
}

/// 표 한 줄: 아이콘 타일 > 항목 · 오른쪽 값
class ElumGuideRow extends StatelessWidget {
  const ElumGuideRow({super.key, required this.iconAsset, required this.label, required this.value});

  final String iconAsset;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => _GuideRowFrame(
    iconAsset: iconAsset,
    label: label,
    value: Text(value, textAlign: TextAlign.end, style: _valueStyle(context)),
  );
}

/// 어절 가운데서 꺾이지 않게 (큰 글자 · 긴 번역)
String _keep(BuildContext context, String text) => keepWords(text, locale: context.appLocale);

TextStyle _valueStyle(BuildContext context) => context.typo.creditTitle.copyWith(color: context.colors.textPrimary);

/// 표 줄 틀: 아이콘 타일 > 항목(늘어남) > 값
class _GuideRowFrame extends StatelessWidget {
  const _GuideRowFrame({required this.iconAsset, required this.label, required this.value});

  final String iconAsset;
  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: (space.xs / 2).h),
      child: Row(
        children: [
          ElumGuideIconTile(iconAsset: iconAsset),
          SizedBox(width: space.sm.w),
          Expanded(child: Text(label, style: context.typo.creditBody.copyWith(color: context.colors.textPrimary))),
          SizedBox(width: space.xs.w),
          value,
        ],
      ),
    );
  }
}

/// 설명 한 줄: 아이콘 타일 > 작은 회색 글 (아이콘 없으면 글만, 가운데)
class ElumGuideNote extends StatelessWidget {
  const ElumGuideNote({super.key, required this.text, this.iconAsset});

  final String text;
  final String? iconAsset;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final iconAsset = this.iconAsset;
    final style = context.typo.creditBody.copyWith(color: context.colors.textSecondary);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: (space.xs / 2).h),
      child: iconAsset == null
          ? Text(_keep(context, text), semanticsLabel: text, textAlign: TextAlign.center, style: style)
          : Row(
              children: [
                ElumGuideIconTile(iconAsset: iconAsset),
                SizedBox(width: space.sm.w),
                Expanded(child: Text(_keep(context, text), semanticsLabel: text, style: style)),
              ],
            ),
    );
  }
}

/// 항목 한 줄: 아이콘 타일 > 굵은 항목 + 아래 회색 설명 (설명 없으면 항목만)
/// 값이 없는 소개 줄 (설계 원리 3줄, 받는 알림 목록)
class ElumGuideFeatureRow extends StatelessWidget {
  const ElumGuideFeatureRow({super.key, required this.iconAsset, required this.title, this.description});

  final String iconAsset;
  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final colors = context.colors;
    final description = this.description;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: (space.xs / 2).h),
      child: Row(
        crossAxisAlignment: description == null ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          ElumGuideIconTile(iconAsset: iconAsset),
          SizedBox(width: space.sm.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _keep(context, title),
                  semanticsLabel: title,
                  style: context.typo.creditBody.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600),
                ),
                if (description != null)
                  Text(
                    _keep(context, description),
                    semanticsLabel: description,
                    style: context.typo.creditBody.copyWith(color: colors.textSecondary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 표와 설명 줄 사이 구분선 (1)
class ElumGuideDivider extends StatelessWidget {
  const ElumGuideDivider({super.key});

  static const _thickness = 1.0;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: context.space.xs.h),
    child: Container(height: _thickness, color: context.colors.creditDivider),
  );
}

