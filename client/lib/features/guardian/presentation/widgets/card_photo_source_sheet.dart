import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../data/card_photo.dart';

/// 사진을 어디서 가져올지 고르는 시트 (#456).
///
/// **임시 시안이다** — 디자이너 확정 전 제시용 목업(`sheet_pick`)을 그대로 옮겼다.
/// 확정되면 문구·간격·아이콘을 시안에 맞춘다. 아이콘은 에셋이 나오기 전이라 Material
/// 글리프를 임시로 쓴다.
///
/// `사진 찍기` / `갤러리에서 고르기` 는 고른 출처를, `닫기`·밖을 누르면 null 을 돌려준다.
/// 아래 안내는 **찍기 전에** 말한다 — 얼굴·개인정보가 사진에 실려 서버로 가면
/// 되돌릴 수 없다(서비스 원칙 2).
class CardPhotoSourceSheet extends StatelessWidget {
  const CardPhotoSourceSheet({super.key});

  static Future<PhotoSource?> show(BuildContext context) {
    return showModalBottomSheet<PhotoSource>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: context.colors.sheetScrim,
      builder: (_) => const CardPhotoSourceSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      // 글자를 키우면 시트가 화면을 넘을 수 있어 스크롤로 받는다
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 14.h),
              // 손잡이는 카드 수정 시트와 같다
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: colors.sheetHandle,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              _Row(
                icon: Icons.photo_camera_outlined,
                label: context.l10n.cardPhotoSourceTake,
                onTap: () => Navigator.of(context).pop(PhotoSource.camera),
              ),
              _Row(
                icon: Icons.photo_library_outlined,
                label: context.l10n.cardPhotoSourceGallery,
                onTap: () => Navigator.of(context).pop(PhotoSource.gallery),
              ),
              _Row(
                icon: Icons.close_rounded,
                label: context.l10n.commonClose,
                onTap: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 24.h),
                child: Text(
                  context.l10n.cardPhotoSourcePrivacy,
                  style: typo.bodySmall.copyWith(
                    color: colors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppPressable(
      onTap: onTap,
      // 아이콘만 있는 줄이 아니지만 이름을 한 덩어리로 못 박아 읽히게 한다
      semanticLabel: label,
      child: ConstrainedBox(
        // 누름 영역 최소 48 — 글자를 키우면 줄이 함께 자란다
        constraints: BoxConstraints(minHeight: 60.h),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
          child: Row(
            children: [
              Icon(icon, size: 24.w, color: colors.textPrimary),
              SizedBox(width: 16.w),
              Expanded(
                child: Text(
                  label,
                  style: context.typo.body.copyWith(
                    color: colors.textPrimary,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
