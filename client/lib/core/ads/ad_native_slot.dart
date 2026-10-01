import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/theme_context_ext.dart';
import 'ad_gate.dart';
import 'ad_ids.dart';
import 'ad_native_loader.dart';

/// 목록 사이에 끼우는 네이티브 광고 한 칸 (#465).
///
/// **로드 전·실패 시 항목 자체가 없다.** 높이도 여백도 0이라 목록은 광고가 없을 때와
/// 똑같다 — 빈 자리를 남기지 않는다. 성공했을 때만 [padding] 과 틀이 생긴다.
///
/// ⚠️ 시안이 없는 임시 모양이다(디자이너 협의 대상). 일과 카드와 헷갈려 눌리면 무효
/// 클릭으로 계정이 정지될 수 있어, 일과 카드(회색 면·테두리 없음)와 다르게 **흰 바탕 +
/// 테두리**에 담고 `광고` 라벨을 반드시 붙인다. 시안이 나오면 시안을 따른다.
///
/// 실패하면 30초·60초 뒤 각 한 번만 다시 시도하고 그만둔다(배너와 같다).
class AdNativeSlot extends ConsumerStatefulWidget {
  const AdNativeSlot({
    super.key,
    required this.placement,
    this.padding = EdgeInsets.zero,
  });

  final AdPlacement placement;

  /// **광고가 뜬 뒤에만** 틀 둘레에 두는 여백. 목록 중간에 넣을 때 광고가 없다고 빈 줄이
  /// 남지 않게 한다. 일과 카드와 떨어뜨려 오클릭을 줄이는 데도 쓴다.
  final EdgeInsets padding;

  /// 테스트가 틀을 찾는 키.
  static const frameKey = Key('광고 틀');

  @override
  ConsumerState<AdNativeSlot> createState() => _AdNativeSlotState();
}

class _AdNativeSlotState extends ConsumerState<AdNativeSlot> {
  static const _retryDelays = [Duration(seconds: 30), Duration(seconds: 60)];

  /// 틀 안쪽 여백 · 라벨↔광고 간격
  static const _pad = 12.0;
  static const _labelGap = 8.0;

  LoadedNative? _native;
  Timer? _retry;
  var _attempt = 0;
  var _disposed = false;
  var _loading = false;
  var _width = 0;

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _native?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading || _native != null || _disposed) return;
    _loading = true;
    LoadedNative? result;
    try {
      result = await ref
          .read(adNativeLoaderProvider)
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
      setState(() => _native = result);
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
        final native = _native;
        if (native == null) return const SizedBox.shrink();

        final colors = context.colors;
        return Padding(
          padding: widget.padding,
          child: DecoratedBox(
            key: AdNativeSlot.frameKey,
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(context.space.cardRadius),
            ),
            child: Padding(
              padding: EdgeInsets.all(_pad.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 광고임을 알리는 라벨 — 일과로 오인해 누르는 것을 막는다. 필수다.
                  Text(
                    '광고',
                    style: context.typo.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: _labelGap.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12.r),
                    child: native.widget,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
