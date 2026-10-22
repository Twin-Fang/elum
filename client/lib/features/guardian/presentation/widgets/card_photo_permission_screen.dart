import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_button.dart';
import '../../../../core/widgets/elum_header.dart';
import '../../../../core/widgets/elum_scaffold.dart';
import '../../../../core/widgets/show_failure.dart';
import '../../data/card_photo.dart';
import '../../data/card_photo_picker.dart';

/// 권한 거부 화면이 돌려주는 선택.
enum PhotoPermissionChoice {
  /// 막힌 쪽 말고 다른 길로 — 카메라가 막혔으면 갤러리, 사진이 막혔으면 카메라.
  alternative,

  /// 뒤로 — 아무 일도 없다.
  back,
}

/// 카메라·사진 접근을 쓸 수 없을 때.
///
/// 거부해도 앱은 계속 돌아야 하므로(docs 08 ⑤) 왜 안 되는지 말하고 **우회 경로**(다른 출처)를 주 버튼으로 둔다.
/// `설정 열기` 는 열 수 있는 휴대폰에서만 보인다([PhotoSettings.available]).
class CardPhotoPermissionScreen extends ConsumerWidget {
  const CardPhotoPermissionScreen({super.key, required this.denied});

  /// 막힌 쪽.
  final PhotoSource denied;

  /// 전체 화면으로 띄운다. 뒤로·시스템 뒤로는 [PhotoPermissionChoice.back] 이다.
  static Future<PhotoPermissionChoice> show(
    BuildContext context,
    PhotoSource denied,
  ) async {
    final choice = await Navigator.of(context, rootNavigator: true)
        .push<PhotoPermissionChoice>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => CardPhotoPermissionScreen(denied: denied),
          ),
        );
    return choice ?? PhotoPermissionChoice.back;
  }

  bool get _cameraDenied => denied == PhotoSource.camera;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final settings = ref.watch(photoSettingsProvider);

    return ElumScaffold(
      onBack: () => Navigator.of(context).pop(PhotoPermissionChoice.back),
      bottomButton: ElumButton(
        label: _cameraDenied
            ? context.l10n.cardPhotoPermissionGallery
            : context.l10n.cardPhotoPermissionTake,
        onPressed: () =>
            Navigator.of(context).pop(PhotoPermissionChoice.alternative),
      ),
      belowButton: settings.available
          ? ElumButton(
              label: context.l10n.cardPhotoPermissionOpenSettings,
              backgroundColor: colors.editChipBg,
              labelColor: colors.textPrimary,
              onPressed: () => _openSettings(context, settings),
            )
          : null,
      // 한 가지 묻는 화면 골격 (§4-3): 왼쪽 제목 > 회색 설명, 아래 주 버튼
      child: SingleChildScrollView(
        child: ElumHeader(
          title: _cameraDenied
              ? context.l10n.cardPhotoPermissionCameraTitle
              : context.l10n.cardPhotoPermissionGalleryTitle,
          description: _cameraDenied
              ? context.l10n.cardPhotoPermissionCameraBody
              : context.l10n.cardPhotoPermissionGalleryBody,
        ),
      ),
    );
  }

  /// 설정을 못 열어도 화면에 남는다 — 갤러리 길이 아직 있다.
  Future<void> _openSettings(
    BuildContext context,
    PhotoSettings settings,
  ) async {
    // await 뒤에는 context 를 읽지 않으므로 문구를 미리 잡아 둔다
    final l10n = context.l10n;
    final opened = await settings.open();
    if (opened || !context.mounted) return;
    await showFailure(
      context,
      null,
      title: l10n.cardPhotoSettingsFailedTitle,
      fallback: l10n.cardPhotoSettingsFailedFallback,
      fallbackCode: 'E-PHOTO-SETTINGS',
    );
  }
}
