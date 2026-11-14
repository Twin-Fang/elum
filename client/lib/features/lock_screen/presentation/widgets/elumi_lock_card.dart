import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/content_locale.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/lock_screen/lock_screen_snapshot.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pop_in.dart';
import '../../../../core/text/keep_words.dart';
import '../../../../shared/example_card_image/bundled_card_art.dart';

/// 이룸이 잠금화면 카드 본문: "지금 할 일" > 큰 그림 한 장 > 짧은 카드 글 (한 화면에 행동 하나)
/// 그림은 기기에 받아 둔 파일 > 번들 그림(예시·픽토그램) > 빈 칸 순서 (네트워크 없음)
class ElumiLockCard extends StatelessWidget {
  const ElumiLockCard({super.key, required this.card});

  final LockScreenElumiCard card;

  /// 그림 한 변 (화면 폭 393 기준 280, 태블릿은 배율로 커짐)
  static const _pictureSize = 280.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final space = context.space;
    final radius = BorderRadius.circular(space.cardRadius.r);
    return ContentLocale(
      language: card.contentLanguage,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            card.routineTitle,
            textAlign: TextAlign.center,
            style: typo.childGreeting.copyWith(color: colors.textSecondary),
          ),
          SizedBox(height: space.md.h),
          AppPopIn(
            child: Container(
              width: _pictureSize.w,
              height: _pictureSize.w,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: radius,
                border: Border.all(color: colors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: _picture(context),
            ),
          ),
          SizedBox(height: space.lg.h),
          Text(
            keepWords(card.cardText, locale: context.appLocale),
            semanticsLabel: card.cardText,
            textAlign: TextAlign.center,
            style: typo.cardHeadline.copyWith(color: colors.textPrimary),
          ),
          SizedBox(height: space.xs.h),
          Text(
            context.l10n.lockScreenElumiNowLabel,
            textAlign: TextAlign.center,
            style: typo.cardDescription.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _picture(BuildContext context) {
    final bundledArt = BundledCardArt(
      label: card.cardText,
      pictogramId: card.pictogramId,
      exampleImageId: card.exampleImageId,
    );
    final imageFilePath = card.imageFilePath;
    if (imageFilePath == null) return bundledArt;
    return Image.file(
      File(imageFilePath),
      fit: BoxFit.cover,
      semanticLabel: card.cardText,
      // 파일이 지워졌으면(로그아웃 정리 등) 번들 그림으로
      errorBuilder: (_, _, _) => bundledArt,
    );
  }
}
