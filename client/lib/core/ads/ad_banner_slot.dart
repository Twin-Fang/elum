import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ad_banner_loader.dart';
import 'ad_gate.dart';
import 'ad_ids.dart';

/// 화면 하단에 놓는 배너 자리.
///
/// **로드 전·실패 시 높이 0이다.** 빈 자리를 남기지 않는다 — 배너가 없으면 화면은
/// 원래 크기 그대로다. 로드에 성공하면 그 높이만큼 본문이 줄어든다(겹치지 않는다).
///
/// 실패하면 30초·60초 뒤 각 한 번만 다시 시도하고 그만둔다.
class AdBannerSlot extends ConsumerStatefulWidget {
  const AdBannerSlot({super.key, required this.placement});

  final AdPlacement placement;

  @override
  ConsumerState<AdBannerSlot> createState() => _AdBannerSlotState();
}

class _AdBannerSlotState extends ConsumerState<AdBannerSlot> {
  static const _retryDelays = [Duration(seconds: 30), Duration(seconds: 60)];

  LoadedBanner? _banner;
  Timer? _retry;
  var _attempt = 0;
  var _disposed = false;
  var _loading = false;
  var _width = 0;

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
      result = await ref
          .read(adBannerLoaderProvider)
          .load(widget.placement, _width);
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth.floor()
            : MediaQuery.sizeOf(context).width.floor();
        if (width > 0 && width != _width) {
          _width = width;
          // 빌드 도중 상태를 바꾸지 않게 첫 프레임 뒤로 미룬다.
          WidgetsBinding.instance.addPostFrameCallback((_) => _load());
        }
        final banner = _banner;
        if (banner == null) return const SizedBox.shrink();
        return SizedBox(
          height: banner.height,
          width: double.infinity,
          child: Center(child: banner.widget),
        );
      },
    );
  }
}
