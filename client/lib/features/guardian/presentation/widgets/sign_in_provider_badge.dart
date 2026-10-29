import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../auth/domain/oauth_provider.dart';

/// 가입한 소셜 제공자 배지: 브랜드 색 둥근 네모 + 로고 (시안 1759:9604)
///
/// 로고 파일은 각 사 브랜드 자산이라 색을 바꾸지 않고 배경만 깐다.
class SignInProviderBadge extends StatelessWidget {
  const SignInProviderBadge({
    super.key,
    required this.provider,
    this.size = defaultSize,
  });

  final OAuthProvider provider;

  /// 배지 한 변 (논리 px, .w 적용 전)
  final double size;

  static const defaultSize = 24.0;

  /// 시안 24 기준 모서리 4, 로고 14 > 크기가 바뀌어도 같은 비율
  static const _radiusRatio = 4 / 24;
  static const _logoRatio = 14 / 24;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final (asset, background, name) = switch (provider) {
      OAuthProvider.kakao => (AppAssets.loginKakao, colors.loginKakaoBg, l10n.signInProviderKakao),
      OAuthProvider.naver => (AppAssets.loginNaver, colors.loginNaverBg, l10n.signInProviderNaver),
      OAuthProvider.apple => (AppAssets.loginApple, colors.loginAppleBg, l10n.signInProviderApple),
      // 구글은 시안에 없음 > 흰 바탕 G 가 흰 카드 위에서 묻히지 않게 화면 바탕색
      OAuthProvider.google => (AppAssets.loginGoogle, colors.background, l10n.signInProviderGoogle),
    };

    return Semantics(
      label: name,
      child: SizedBox(
        width: size.w,
        height: size.w,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular((size * _radiusRatio).r),
          ),
          child: Center(
            child: SvgPicture.asset(
              asset,
              width: (size * _logoRatio).w,
              height: (size * _logoRatio).w,
            ),
          ),
        ),
      ),
    );
  }
}
