package kr.twinfang.elum.widget

import kr.twinfang.elum.lockscreen.LockScreenElumiCard

/**
 * 위젯 "다 했어요" 버튼 동작 4종 (설계 2026-11-18-widget-card-check 구현 약속, iOS 와 같은 규칙)
 * QUEUE 대기열에 넣기, OPEN_APP_CHECK 앱 열어 체크(마지막 카드), CONTINUE_IN_APP 받아 둔 카드 소진, NONE 버튼 없음
 */
enum class ElumWidgetCheckMode { QUEUE, OPEN_APP_CHECK, CONTINUE_IN_APP, NONE }

/** 위젯이 보여 줄 카드 한 장 (지금 카드 또는 앱 없이 넘긴 다음 카드) */
data class ElumWidgetDisplayCard(
    val routineId: String,
    val routineTitle: String,
    val cardId: String,
    val cardText: String,
    val imageFilePath: String?,
)

/**
 * 지금 할 카드 위젯 체크 상태: 요약 카드 + 위젯에서 체크한 카드 > 보여 줄 카드·남은 수·버튼 동작
 * 보여 줄 카드 = [지금 카드] + 다음 카드 중 체크 안 한 첫 장 · 남은 수 = remainingCount − 체크한 수
 */
class ElumWidgetCardCheck private constructor(
    // null: CONTINUE_IN_APP (받아 둔 카드 소진)
    val displayCard: ElumWidgetDisplayCard?,
    val routineId: String,
    val routineTitle: String,
    val remainingCount: Int,
    val mode: ElumWidgetCheckMode,
) {
    companion object {
        /**
         * 체크 가능(이룸이 기기 + 오늘 요약 + cardId·남은 수 있음)일 때만 대기열 반영, 아니면 요약 카드 그대로 + NONE
         */
        fun of(card: LockScreenElumiCard, canCheck: Boolean, checkedCardIds: Set<String>): ElumWidgetCardCheck {
            val snapshotCard = ElumWidgetDisplayCard(
                routineId = card.routineId,
                routineTitle = card.routineTitle,
                cardId = card.cardId,
                cardText = card.cardText,
                imageFilePath = card.imageFilePath,
            )
            val isCheckable = canCheck && card.cardId.isNotEmpty() && card.remainingCount > 0
            if (!isCheckable) {
                return ElumWidgetCardCheck(snapshotCard, card.routineId, card.routineTitle, card.remainingCount, ElumWidgetCheckMode.NONE)
            }
            // 후보 카드 (지금 카드 > 다음 카드 순)
            val candidates = listOf(snapshotCard) + card.upcomingCards.map {
                ElumWidgetDisplayCard(card.routineId, card.routineTitle, it.cardId, it.cardText, it.imageFilePath)
            }
            val checkedCount = candidates.count { it.cardId in checkedCardIds }
            val displayCard = candidates.firstOrNull { it.cardId !in checkedCardIds }
            val remainingCount = card.remainingCount - checkedCount
            val mode = when {
                displayCard == null -> ElumWidgetCheckMode.CONTINUE_IN_APP
                remainingCount >= 2 -> ElumWidgetCheckMode.QUEUE
                remainingCount == 1 -> ElumWidgetCheckMode.OPEN_APP_CHECK
                // 남은 수 0 이하인데 카드가 남음 (요약 어긋남) > 앱에서 이어서
                else -> ElumWidgetCheckMode.CONTINUE_IN_APP
            }
            val shownCard = displayCard.takeIf { mode != ElumWidgetCheckMode.CONTINUE_IN_APP }
            return ElumWidgetCardCheck(shownCard, card.routineId, card.routineTitle, remainingCount, mode)
        }
    }
}
