import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_context_ext.dart';

import '../data/ad_banner_loader.dart' show LoadedBanner;
import '../data/ad_strip_loader.dart';
import '../application/ad_gate.dart';
import '../../../core/config/ad_ids.dart';

/// 화면 하단 한 줄(44dp) 네이티브 광고 띠: 자리 고정, 위 간격, 앱 색 토큰 띠 색
/// 광고 계정이면 로드 전·실패에도 높이 유지 (늦게 떠 하단 바를 밀면 오클릭, #1168) · 광고 없앤 요금제·확인 전 0
///
/// 실패 시 30초·60초 뒤 한 번씩 재시도 후 중단 (빈 띠 유지). 색이 바뀌면 같은 자리에 다시 로드.
class AdBottomStripSlot extends ConsumerStatefulWidget {
  const AdBottomStripSlot({super.key, required this.placement});

  final AdPlacement placement;

  /// 테스트가 층을 찾는 키.
  static const stripKey = Key('광고 배너 층');

  @override
  ConsumerState<AdBottomStripSlot> createState() => _AdBottomStripSlotState();
}

class _AdBottomStripSlotState extends ConsumerState<AdBottomStripSlot> {
  // 테마 전환 애니메이션 중간 색마다 다시 요청하지 않게 기다리는 시간
  static const _colorSettleDelay = Duration(milliseconds: 500);
  static const _retryDelays = [Duration(seconds: 30), Duration(seconds: 60)];

  LoadedBanner? _banner;
  Timer? _retry;
  Timer? _colorReloadTimer;
  var _attempt = 0;
  var _disposed = false;
  var _loading = false;
  AdStripColors? _requestedColors;
  var _isLoadStarted = false;

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _colorReloadTimer?.cancel();
    _banner?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 앱 색 토큰 > 띠 색 (앱 콘텐츠와 면·글자색으로 갈라 광고임을 알아보게 한다)
    final colors = context.colors;
    final stripColors = AdStripColors(
      background: colors.surface.toARGB32(),
      headline: colors.textPrimary.toARGB32(),
      callToAction: colors.buttonEnabled.toARGB32(),
      badgeBackground: colors.border.toARGB32(),
      badgeText: colors.textSecondary.toARGB32(),
    );
    if (stripColors == _requestedColors) return;
    final isFirstRequest = _requestedColors == null;
    _requestedColors = stripColors;
    if (isFirstRequest) return;

    // 색 전환 (라이트·다크): 테마 전환 애니메이션이 끝나 색이 멈춘 뒤 한 번만 다시 로드
    _colorReloadTimer?.cancel();
    _colorReloadTimer = Timer(_colorSettleDelay, _reloadWithLatestColors);
  }

  void _reloadWithLatestColors() {
    if (_disposed) return;
    // 이전 띠 해제 > 재시도 횟수 초기화 > 새 색으로 다시 로드
    _retry?.cancel();
    _attempt = 0;
    final previous = _banner;
    if (previous != null) {
      setState(() => _banner = null);
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
    _load();
  }

  Future<void> _load() async {
    final colors = _requestedColors;
    if (_loading || _banner != null || _disposed || colors == null) return;
    _loading = true;
    LoadedBanner? result;
    try {
      result = await ref
          .read(adStripLoaderProvider)
          .load(widget.placement, colors);
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

    // 광고가 허용된 뒤 첫 빌드에서 한 번만 요청 (빌드 도중 상태를 바꾸지 않게 프레임 뒤로)
    if (!_isLoadStarted) {
      _isLoadStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    // 띠를 화면 폭 전체의 얇은 층에 담는다: 위 간격 + 면 색 + 윗선으로 본문과 구분
    final colors = context.colors;
    return Padding(
      // 하단 바·버튼 <-> 광고 사이 간격 (오클릭 방지)
      padding: EdgeInsets.only(top: context.space.xs),
      child: DecoratedBox(
        key: AdBottomStripSlot.stripKey,
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.border)),
        ),
        child: SizedBox(
          // 로드 전·후·실패 공통 높이 (광고가 떠도 위 요소가 움직이지 않음)
          height: GoogleAdStripLoader.stripHeight,
          width: double.infinity,
          child: _banner?.widget,
        ),
      ),
    );
  }
}
