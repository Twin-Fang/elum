import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/layout/share_origin.dart';
import '../../../../core/router/pop_or_home.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_error_view.dart';
import '../../../../core/widgets/elum_scaffold.dart';
import '../../../../core/widgets/elum_sheet_action_row.dart';
import '../../../../core/widgets/elum_state_body.dart';
import '../../../../core/widgets/pro_teaser.dart';
import '../../../../core/widgets/show_failure.dart';
import '../../../member/application/plan_access.dart';
import '../../../subscription/application/plan_paywall_entry.dart';
import '../../../subscription/domain/plan_benefit.dart';
import '../../application/guardian_child_identity.dart';
import '../../application/weekly_report_providers.dart';
import '../../data/card_export_files.dart';
import '../../domain/weekly_report.dart';
import '../card_export/print_page.dart';
import '../pro_teaser_samples.dart';
import 'weekly_report_sections.dart';
import 'weekly_report_share_page.dart';
import 'weekly_report_week_picker.dart';

/// 화면 에러 코드 (서버 코드가 없을 때 보임)
abstract final class WeeklyReportErrorCode {
  static const load = 'E-WEEKLY-REPORT';
  static const share = 'E-WEEKLY-REPORT-SHARE';
}

/// 주간 리포트 (#1074, Pro): 주 고르기 > 요약·기록 > 보낼 한 장 미리 보기 > 이미지·PDF 로 보내기
///
/// 상태 4개: 불러오는 중 / 보낸 일과 0건(빈 상태) / 실패(에러 코드 + 다시 하기) / 리포트.
/// Free: 판매 중이면 흐린 견본 리포트 + `Pro로 보기`, 아니면 입구가 없다 (그래도 들어오면 안내만).
class WeeklyReportScreen extends ConsumerStatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  ConsumerState<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends ConsumerState<WeeklyReportScreen> {
  static const _backTop = ElumScaffold.settingsBackTop;
  static const _horizontalPadding = 16.0;
  static const _pickerTopGap = 8.0;
  static const _sectionGap = 16.0;
  static const _previewGap = 24.0;
  static const _labelGap = 8.0;
  static const _files = CardExportFiles();

  final _sharePageKey = GlobalKey();
  bool _isSharing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final access = ref.watch(planAccessProvider);
    final weekStart = ref.watch(weeklyReportWeekProvider);
    final weekNotifier = ref.read(weeklyReportWeekProvider.notifier);
    final reportAsync = access.canViewWeeklyReport ? ref.watch(weeklyReportProvider(weekStart)) : null;
    final report = reportAsync?.value;
    final canShare = report != null && report.hasRecords && !reportAsync!.isLoading;

    return ElumScaffold(
      onBack: context.popOrHome,
      title: l10n.weeklyReportTitle,
      backTop: _backTop,
      horizontalPadding: _horizontalPadding,
      bottomButton: canShare
          ? ElumSheetActionRow(
              cancelLabel: l10n.weeklyReportShareImage,
              onCancel: _isSharing ? null : () => _share(report, asPdf: false),
              confirmLabel: l10n.weeklyReportSharePdf,
              onConfirm: _isSharing ? null : () => _share(report, asPdf: true),
              isLoading: _isSharing,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: _pickerTopGap.h),
          if (access.canViewWeeklyReport) ...[
            WeeklyReportWeekPicker(
              weekStart: weekStart,
              isCurrentWeek: !weekNotifier.canShowNextWeek,
              onPreviousWeek: weekNotifier.showPreviousWeek,
              onNextWeek: weekNotifier.showNextWeek,
            ),
            SizedBox(height: _sectionGap.h),
          ],
          Expanded(child: _body(context, reportAsync, weekStart)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, AsyncValue<WeeklyReport>? reportAsync, DateTime weekStart) {
    final l10n = context.l10n;
    // Pro 가 아님: 앱 판정(null) 또는 서버 Pro 거절(WEEKLY_REPORT_NOT_ALLOWED) > 실패 대신 미리 보기·안내
    final isNotIncluded = reportAsync == null ||
        (reportAsync is AsyncError && isProOnlyRejection(reportAsync.error));
    if (isNotIncluded) {
      if (ref.watch(planAccessProvider).shouldPromoteBenefit(PlanBenefit.weeklyReport)) {
        return SingleChildScrollView(
          child: ProTeaser(
            benefit: l10n.proTeaserWeeklyReportBenefit,
            onUnlock: () => openPlanPaywall(context, ref),
            child: ProTeaserSamples.weeklyReportSections(context),
          ),
        );
      }
      return ElumStateBody(child: ElumErrorView(message: l10n.weeklyReportNotIncluded, compact: true));
    }
    return switch (reportAsync) {
      AsyncData(value: final report) when !report.hasRecords => const ElumStateBody(child: _EmptyBody()),
      AsyncData(value: final report) => _reportBody(context, report),
      AsyncError(:final error) => ElumStateBody(
        child: ElumErrorView.failure(
          error,
          fallback: l10n.weeklyReportLoadFailed,
          fallbackCode: WeeklyReportErrorCode.load,
          onRetry: () => ref.invalidate(weeklyReportProvider(weekStart)),
        ),
      ),
      _ => const ElumStateBody.loading(),
    };
  }

  Widget _reportBody(BuildContext context, WeeklyReport report) {
    final l10n = context.l10n;
    final colors = context.colors;
    final elumiName = ref.watch(guardianChildIdentityProvider.select((identity) => identity.name));
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WeeklyReportSections(report: report),
          SizedBox(height: _previewGap.h),
          Text(
            l10n.weeklyReportSharePreview,
            style: context.typo.settingsGroupLabel.copyWith(color: colors.settingsGroupLabel),
          ),
          SizedBox(height: _labelGap.h),
          // 미리 보기 = 굽는 지면 그대로 (화면 폭에 맞춰 줄여 보임)
          DecoratedBox(
            decoration: BoxDecoration(border: Border.all(color: colors.border)),
            child: FittedBox(
              fit: BoxFit.contain,
              child: RepaintBoundary(
                key: _sharePageKey,
                child: WeeklyReportSharePage(report: report, elumiName: elumiName),
              ),
            ),
          ),
          SizedBox(height: _labelGap.h),
          Text(
            l10n.weeklyReportSharePreviewCaption,
            style: context.typo.caption.copyWith(color: colors.textSecondary),
          ),
          SizedBox(height: _previewGap.h),
        ],
      ),
    );
  }

  // 미리 보기 지면 굽기 > PNG 또는 A4 PDF > 공유 시트
  Future<void> _share(WeeklyReport report, {required bool asPdf}) async {
    final l10n = context.l10n;
    final origin = shareOriginOf(context);
    final elumiName = ref.read(guardianChildIdentityProvider).name;
    setState(() => _isSharing = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _sharePageKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) throw StateError('weekly report page not painted');
      final png = await _files.capturePng(boundary, PrintPageSize.a4PixelRatio);
      final stem = '${exportFileStem(l10n.weeklyReportShareTitle(elumiName))}_${_dateStamp(report.weekStart)}';
      if (asPdf) {
        final pdf = await _files.buildA4Pdf([png]);
        await _files.share(
          files: [(fileName: '$stem.pdf', bytes: pdf, mimeType: 'application/pdf')],
          sharePositionOrigin: origin,
        );
      } else {
        await _files.share(
          files: [(fileName: '$stem.png', bytes: png, mimeType: 'image/png')],
          sharePositionOrigin: origin,
        );
      }
    } on Object catch (error) {
      if (!mounted) return;
      await showFailure(
        context,
        error,
        fallback: l10n.weeklyReportShareFailed,
        fallbackCode: WeeklyReportErrorCode.share,
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  /// 주 시작 > `20261102` (파일 이름 끝)
  static String _dateStamp(DateTime date) =>
      '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
}

/// 보낸 일과 0건: 글만 (보호자 빈 상태는 그림 없음)
class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.weeklyReportEmptyTitle,
          textAlign: TextAlign.center,
          style: context.typo.creditHistoryRowTitle.copyWith(color: colors.settingsCardLabel),
        ),
        SizedBox(height: context.space.xs),
        Text(
          context.l10n.weeklyReportEmptyBody,
          textAlign: TextAlign.center,
          style: context.typo.creditHistoryRowDetail.copyWith(color: colors.settingsGroupLabel),
        ),
      ],
    );
  }
}
