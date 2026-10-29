import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/layout/share_origin.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_error_view.dart';
import '../../../core/widgets/elum_state_body.dart';
import '../../../core/widgets/elum_toast.dart';
import '../../../core/widgets/show_failure.dart';
import '../../../shared/models/action_card.dart';
import '../../profile/application/invite_sharer.dart';
import '../application/talk_link_actions.dart';
import '../application/talk_share_controller.dart';
import '../application/talk_shareable_routines_provider.dart';
import '../domain/talk_post_link.dart';
import '../domain/talk_screen_codes.dart';
import 'widgets/talk_page_heading.dart';
import 'widgets/talk_photo_blur_picker.dart';
import 'widgets/talk_share_bottom_button.dart';
import 'widgets/talk_top_bar.dart';

/// 일과를 링크로 보내기: 미리보기(이름 가린 글) > 사진 흐리게(사진 카드가 있고 처음 보낼 때만) > 링크 만들기 > 공유 시트 > 닫기
/// 이미 켜진 링크가 있으면 서버가 그 링크를 돌려주므로 사진 단계 없이 안내만 바꾼다
class TalkLinkShareScreen extends ConsumerStatefulWidget {
  const TalkLinkShareScreen({
    super.key,
    required this.routineId,
    this.hasActiveLink = false,
  });

  /// 보낼 일과관리 원본 id
  final String routineId;

  /// 이 일과의 켜진 링크가 이미 있는가 (일과관리 메뉴가 넘긴다)
  final bool hasActiveLink;

  @override
  ConsumerState<TalkLinkShareScreen> createState() =>
      _TalkLinkShareScreenState();
}

class _TalkLinkShareScreenState extends ConsumerState<TalkLinkShareScreen> {
  final _buttonKey = GlobalKey();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPreview());
  }

  // 올리기 흐름의 미리보기·흐리게 선택 상태를 함께 쓴다 (분류·한마디는 쓰지 않음)
  Future<void> _loadPreview() => ref
      .read(talkShareControllerProvider.notifier)
      .selectRoutine(widget.routineId, context.l10n);

  /// 사진을 고르는 화면인가 (처음 보내고 보호자 사진 카드가 있을 때)
  bool _isPhotoStage(TalkShareState state) =>
      !widget.hasActiveLink && state.hasGuardianPhoto;

  /// 링크 만들기 > 공유 시트 > 닫고 토스트. 실패하면 화면을 두고 에러 코드가 붙은 팝업
  Future<void> _submit(TalkShareState state) async {
    final preview = state.preview;
    if (preview == null || _isSubmitting) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final buttonContext = _buttonKey.currentContext;
    final origin = buttonContext == null ? null : shareOriginOf(buttonContext);
    setState(() => _isSubmitting = true);
    try {
      final created = await ref
          .read(talkLinkActionsProvider)
          .create(
            routineId: widget.routineId,
            blurredStepIds: state.blurredStepIds,
          );
      if (!mounted) return;
      await _openShareSheet(preview.title, created.postId, origin);
      if (!mounted) return;
      showElumToastOn(messenger, l10n.talkLinkCreated);
      context.popOrHome();
    } catch (e) {
      if (!mounted) return;
      await showFailure(
        context,
        e,
        title: l10n.talkLinkCreateFailedTitle,
        fallback: l10n.talkFailedFallback,
        fallbackCode: TalkScreenCodes.routineLink,
      );
    } finally {
      // 성공·실패 공통: 화면이 남아 있으면 버튼을 다시 살린다
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// 공유 시트 (링크는 이미 만들어졌으므로 시트 실패는 링크 공유 코드로 알리고 화면은 닫는다)
  Future<void> _openShareSheet(
    String title,
    String postId,
    Rect? origin,
  ) async {
    final l10n = context.l10n;
    final message = l10n.talkLinkShareMessage(
      title,
      TalkPostLink.shareUrl(AppConfig.apiBaseUrl, postId),
    );
    try {
      await ref.read(inviteSharerProvider)(message, origin);
    } catch (e) {
      if (!mounted) return;
      await showFailure(
        context,
        e,
        fallback: l10n.talkShareLinkFailed,
        fallbackCode: TalkScreenCodes.shareLink,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(talkShareControllerProvider);
    final isLoaded =
        state.preview != null && state.routineId == widget.routineId;
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Column(
        children: [
          TalkTopBar(
            title: context.l10n.talkLinkSend,
            onBackPressed: context.popOrHome,
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: SafeArea(
                    top: false,
                    bottom: !isLoaded,
                    child: isLoaded ? _scrollBody(state) : _previewBody(state),
                  ),
                ),
                if (isLoaded)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: KeyedSubtree(
                      key: _buttonKey,
                      child: TalkShareBottomButton(
                        label: context.l10n.talkLinkCreateButton,
                        isLoading: _isSubmitting,
                        onPressed: state.hasChosenAllPhotos && !_isSubmitting
                            ? () => _submit(state)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 미리보기 받는 중 / 실패(다시 하기 + 에러 코드)
  Widget _previewBody(TalkShareState state) {
    final failure = state.previewFailure;
    if (failure == null || state.routineId != widget.routineId) {
      return const ElumStateBody.loading();
    }
    return ElumStateBody(
      child: ElumErrorView.failure(
        failure,
        fallback: context.l10n.talkLinkPreviewFailed,
        fallbackCode: TalkScreenCodes.routineLink,
        onRetry: _loadPreview,
      ),
    );
  }

  Widget _scrollBody(TalkShareState state) {
    final l10n = context.l10n;
    final space = context.space;
    final preview = state.preview;
    if (preview == null) return const ElumStateBody.loading();
    return SingleChildScrollView(
      // 마지막 줄이 버튼 띠 위까지 올라오게 띠 높이만큼 비운다
      padding: EdgeInsets.fromLTRB(
        space.md.w,
        TalkPageHeading.topSpacing.h,
        space.md.w,
        TalkShareBottomButton.heightOf(context) + space.lg.h,
      ),
      child: _isPhotoStage(state)
          ? TalkPhotoBlurPicker(
              routineId: widget.routineId,
              photoSteps: [
                for (final step in preview.steps)
                  if (step.isGuardianPhoto) step,
              ],
              cardByStepId: _cardByStepId(),
              blurChoiceByStepId: state.blurChoiceByStepId,
              onChoose: ref
                  .read(talkShareControllerProvider.notifier)
                  .chooseBlur,
              isEnabled: !_isSubmitting,
              title: l10n.talkLinkPhotoTitle,
              guide: l10n.talkLinkPhotoGuide,
            )
          : TalkPageHeading(
              title: l10n.talkLinkConfirmTitle,
              description: widget.hasActiveLink
                  ? l10n.talkLinkResendGuide
                  : l10n.talkLinkConfirmGuide,
            ),
    );
  }

  /// 사진 칸에 그릴 일과관리 원본 카드 (카드 id > 카드)
  Map<String, ActionCard> _cardByStepId() {
    final sourceRoutine = ref.watch(
      talkShareSourceRoutineProvider(widget.routineId),
    );
    return {
      for (final card in sourceRoutine?.steps ?? const <ActionCard>[])
        card.id: card,
    };
  }
}
