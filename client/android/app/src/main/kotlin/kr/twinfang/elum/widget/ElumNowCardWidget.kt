package kr.twinfang.elum.widget

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import kr.twinfang.elum.MainActivity
import kr.twinfang.elum.R

/**
 * 지금 할 카드 위젯 (2x2 기본, 4x4 까지): 카드 그림 + 카드 글 + 일과 제목 + n/m + "다 했어요" > 누르면 그 일과
 * 카드 없으면 오늘 루미와 같은 상태 화면 > 누르면 홈
 * 크기 3단계: 소(그림 위 · 글 아래), 중(그림 왼쪽), 대(큰 그림 + 큰 글)
 * 버튼 동작은 ElumWidgetCardCheck (대기열 · 앱 열어 체크 · 앱에서 이어서 · 없음)
 */
class ElumNowCardWidget : ElumWidgetProvider() {
    override val sourceName: String = "now_card"

    override val sizeSteps: List<SizeF> = listOf(SMALL_SIZE, MEDIUM_SIZE, LARGE_SIZE)

    override fun buildViews(context: Context, state: ElumWidgetState, sizeStepIndex: Int): RemoteViews {
        val check = state.nowCardCheck
            ?: return ElumWidgetViews.buildTodayViews(
                context,
                state,
                isMedium = sizeStepIndex == MEDIUM_STEP_INDEX,
                // 대 크기에 중 배치를 쓰면 아래가 텅 빔 > 루미 가운데 크게
                isLarge = sizeStepIndex > MEDIUM_STEP_INDEX,
            )
        val layout = when (sizeStepIndex) {
            SMALL_STEP_INDEX -> R.layout.widget_now_small
            MEDIUM_STEP_INDEX -> R.layout.widget_now_medium
            else -> R.layout.widget_now_large
        }
        val views = RemoteViews(context.packageName, layout)
        // 소 레이아웃은 일과 제목 칸 없음 (좁아서 카드 글만, 칭찬은 그림 위 배지)
        val hasRoutineTitleRow = sizeStepIndex != SMALL_STEP_INDEX
        bindCard(context, views, state, check)
        bindCheckPraise(views, state, check, hasRoutineTitleRow)
        bindCheckButton(context, views, state, check)
        return views
    }

    override fun routeOf(state: ElumWidgetState): String =
        state.nowCardCheck?.let { ElumWidgetRoutes.routineRoute(it.routineId) } ?: ElumWidgetRoutes.ROUTE_HOME

    // 카드 그림 (파일 > 루미가 카드 든 그림), 카드 글 (소진이면 "앱에서 이어서 해요"), n/m 칩
    private fun bindCard(context: Context, views: RemoteViews, state: ElumWidgetState, check: ElumWidgetCardCheck) {
        val card = check.displayCard
        val picture = state.nowCardPicture
        if (card != null && picture != null) {
            views.setImageViewBitmap(R.id.widget_card_image, picture)
        } else {
            views.setImageViewResource(R.id.widget_card_image, R.drawable.lumi_holding_card)
        }
        val cardText = card?.cardText ?: context.getString(R.string.widget_continue_in_app)
        views.setTextViewText(R.id.widget_card_text, cardText)
        views.setTextViewText(
            R.id.widget_count_chip,
            context.getString(R.string.widget_progress_count, state.doneCount, state.totalCount),
        )
    }

    // 체크 뒤 10분: 루미 cheer + "잘했어요!" (중·대는 일과 제목 자리를 바꿈)
    private fun bindCheckPraise(
        views: RemoteViews,
        state: ElumWidgetState,
        check: ElumWidgetCardCheck,
        hasRoutineTitleRow: Boolean,
    ) {
        val shouldShowPraise = state.shouldShowCheckPraise
        views.setViewVisibility(R.id.widget_check_praise_row, if (shouldShowPraise) View.VISIBLE else View.GONE)
        if (!hasRoutineTitleRow) return
        views.setViewVisibility(R.id.widget_routine_title, if (shouldShowPraise) View.GONE else View.VISIBLE)
        views.setTextViewText(R.id.widget_routine_title, check.routineTitle)
    }

    // 버튼: 대기열 > 체크 수신기 · 마지막 카드 > 앱 check 경로 · 그 밖은 숨김 (위젯 나머지는 원래 탭 경로)
    private fun bindCheckButton(context: Context, views: RemoteViews, state: ElumWidgetState, check: ElumWidgetCardCheck) {
        val card = check.displayCard
        val dateKey = state.snapshot?.dateKey
        val pendingIntent = when {
            card == null || dateKey == null -> null
            check.mode == ElumWidgetCheckMode.QUEUE ->
                ElumWidgetCheckReceiver.pendingIntentOf(context, card.routineId, card.cardId, dateKey)
            check.mode == ElumWidgetCheckMode.OPEN_APP_CHECK ->
                openAppCheckIntentOf(context, card)
            else -> null
        }
        if (pendingIntent == null) {
            views.setViewVisibility(R.id.widget_check_button, View.GONE)
            return
        }
        views.setViewVisibility(R.id.widget_check_button, View.VISIBLE)
        views.setOnClickPendingIntent(R.id.widget_check_button, pendingIntent)
    }

    // 앱 열기 check:<일과 id>:<카드 id> (action 으로 위젯 탭 intent 와 구분, 카드마다 요청 코드)
    private fun openAppCheckIntentOf(context: Context, card: ElumWidgetDisplayCard): PendingIntent {
        val intent = Intent(context, MainActivity::class.java)
            .setAction(ACTION_OPEN_APP_CHECK)
            .putExtra(ElumWidgetRoutes.EXTRA_ROUTE, ElumWidgetRoutes.checkRoute(card.routineId, card.cardId))
            .putExtra(ElumWidgetRoutes.EXTRA_SOURCE, sourceName)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(
            context,
            card.cardId.hashCode(),
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    companion object {
        // 크기 단계 최소 크기 (dp): 소 2x2, 중 4x2, 대 4x4
        val SMALL_SIZE = SizeF(110f, 110f)
        val MEDIUM_SIZE = SizeF(220f, 110f)
        val LARGE_SIZE = SizeF(220f, 220f)
        private const val SMALL_STEP_INDEX = 0
        private const val MEDIUM_STEP_INDEX = 1
        private const val ACTION_OPEN_APP_CHECK = "kr.twinfang.elum.widget.ACTION_OPEN_APP_CHECK"
    }
}
