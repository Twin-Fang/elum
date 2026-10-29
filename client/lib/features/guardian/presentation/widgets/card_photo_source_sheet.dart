import 'package:flutter/material.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';
import '../../../../core/widgets/elum_sheet_frame.dart';
import '../../data/card_photo.dart';
import 'library_quick_menu.dart';

/// 사진을 어디서 가져올지 고르는 시트: 흰 묶음 판 안 `사진 찍기` · `갤러리에서 고르기`
///
/// 고른 출처를 돌려주고, 손잡이로 내리거나 뒤 막을 누르면 null 을 돌려준다.
/// 제목에 맞는 문구가 없어 제목 없는 메뉴 시트로 둔다 (빠른 메뉴 시트와 같은 줄).
class CardPhotoSourceSheet extends StatelessWidget {
  const CardPhotoSourceSheet({super.key});

  static Future<PhotoSource?> show(BuildContext context) {
    return showElumSheet<PhotoSource>(
      context: context,
      builder: (_) => const CardPhotoSourceSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ElumSheetFrame(
      child: QuickMenuGroup<PhotoSource>(
        rows: [
          (
            value: PhotoSource.camera,
            icon: AppAssets.iconCamera,
            label: l10n.cardPhotoSourceTake,
            isDanger: false,
          ),
          (
            value: PhotoSource.gallery,
            icon: AppAssets.iconPicture,
            label: l10n.cardPhotoSourceGallery,
            isDanger: false,
          ),
        ],
      ),
    );
  }
}
