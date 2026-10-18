import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/theme_context_ext.dart';

import '../data/ad_banner_loader.dart';
import '../application/ad_gate.dart';
import '../../../core/config/ad_ids.dart';

/// 배너가 놓이는 모양.
enum AdBannerStyle {
  /// 화면 맨 아래 얇은 한 줄: 본문과 같은 배경 + 윗선
  bottomStrip,

  /// 목록 사이 카드: `광고` 라벨 + 테두리 틀 (일과 카드와 구분해 오클릭 방지)
  inlineCard,
}

/// 배너 자리: 화면 하단 한 줄 또는 목록 사이 카드. 광고는 표준 배너(50dp) 하나다.
///
/// **로드 전·실패 시 높이 0이다.** 빈 자리를 남기지 않는다 — 배너가 없으면 화면은
/// 본래 크기 그대로다. 로드에 성공하면 그 높이만큼 본문이 줄어든다(겹치지 않는다).
///
/// 실패하면 30초·60초 뒤 각 한 번만 다시 시도하고 그만둔다.
class AdBannerSlot extends ConsumerStatefulWidget {
  const AdBannerSlot({
    super.key,
    required this.placement,
    this.style = AdBannerStyle.bottomStrip,
    this.padding = EdgeInsets.zero,
  });

  final AdPlacement placement;

  final AdBannerStyle style;

  /// **광고가 뜬 뒤에만** 배너 둘레에 두는 여백. 광고가 없으면 이 여백도 없다 — 목록 중간에 넣을 때 광고가
  /// 없다고 빈 줄이 남지 않게 한다. 눌러도 되는 다른 요소와 떨어뜨리는 데도 쓴다(오클릭 방지).
  final EdgeInsets padding;

  /// 테스트가 하단 층을 찾는 키.
  static const stripKey = Key('광고 배너 층');

  /// 테스트가 목록 사이 틀을 찾는 키.
  static const frameKey = Key('광고 틀');

  @override
  ConsumerState<AdBannerSlot> createState() => _AdBannerSlotState();
}

class _AdBannerSlotState extends ConsumerState<AdBannerSlot> {
  static const _retryDelays = [Duration(seconds: 30), Duration(seconds: 60)];

  /// 목록 사이 틀: 안쪽 여백 · 라벨↔배너 간격
  static const _framePadding = 12.0;
  static const _labelGap = 6.0;

  LoadedBanner? _banner;
  Timer? _retry;
  var _attempt = 0;
  var _disposed = false;
  var _loading = false;
  var _isRequested = false;

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _banner?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading || _banner != null || _disposed) return;
    _loading = true;
    LoadedBanner? result;
    try {
      result = await ref.read(adBannerLoaderProvider).load(widget.placement);
    } catch (_) {
      // 로더가 예외를 던져도 화면은 살아 있어야 한다. 실패로 취급한다.
      result = null;
    }
    _loading = false;
    if (_disposed) {
      // 늦게 끝났는데 화면이 이미 없다 — 그리지 않고 해제한다.
      result?.dispose();
      return;
    }
    if (result != null) {
      setState(() => _banner = result);
      return;
    }
    if (_attempt < _retryDelays.length) {
      _retry = Timer(_retryDelays[_attempt++], _load);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(adsEnabledProvider)) return const SizedBox.shrink();

    if (!_isRequested) {
      _isRequested = true;
      // 빌드 도중 상태를 바꾸지 않게 첫 프레임 뒤로 미룬다.
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    final banner = _banner;
    if (banner == null) return const SizedBox.shrink();

    return Padding(
      padding: widget.padding,
      child: switch (widget.style) {
        AdBannerStyle.bottomStrip => _buildBottomStrip(banner),
        AdBannerStyle.inlineCard => _buildInlineCard(banner),
      },
    );
  }

  /// 화면 폭 전체의 얇은 층: 본문과 같은 배경 + 윗선으로만 구분
  Widget _buildBottomStrip(LoadedBanner banner) {
    final colors = context.colors;
    return DecoratedBox(
      key: AdBannerSlot.stripKey,
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SizedBox(
        height: banner.height,
        width: double.infinity,
        child: Center(child: banner.widget),
      ),
    );
  }

  /// 광고임을 알리는 라벨(필수) + 배너를 테두리 틀에 담는다
  Widget _buildInlineCard(LoadedBanner banner) {
    final colors = context.colors;
    return DecoratedBox(
      key: AdBannerSlot.frameKey,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(context.space.cardRadius),
      ),
      child: Padding(
        padding: EdgeInsets.all(_framePadding.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.commonAd,
              style: context.typo.caption.copyWith(color: colors.textSecondary),
            ),
            SizedBox(height: _labelGap.h),
            Center(child: banner.widget),
          ],
        ),
      ),
    );
  }
}
