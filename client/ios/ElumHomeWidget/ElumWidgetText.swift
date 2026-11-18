import Foundation

// 위젯 문구 5개 언어 (기기 언어 > 없으면 한국어). 말투: 루미가 말 거는 해요체, 겁주지 않음 (#1465)
// Android res/values*/strings.xml 의 widget_* 와 같은 뜻 · 이름이 들어가는 문구는 조사 문제로 쓰지 않음
enum ElumWidgetText {
  private static let table: [String: [String: String]] = [
    "ko": [
      "stale.guardian": "루미랑 오늘 일과 볼까요?", "stale.elumi": "루미랑 오늘 할 일 볼까요?",
      "empty.guardian": "오늘 일과를 만들어 볼까요?", "empty.elumi": "오늘은 쉬는 날이에요",
      "done.guardian": "오늘 일과를 다 했어요!", "done.elumi": "오늘 다 했어요! 최고예요",
      "night": "내일 또 같이 해요", "evening": "루미가 기다리고 있어요",
      "morning.guardian": "좋은 아침! 오늘 일과 %d개", "morning.elumi": "좋은 아침! 오늘 할 일 %d개",
      "ready.guardian": "오늘 일과 %d개가 기다려요", "ready.elumi": "시작해 볼까요? 할 일 %d개",
      "progress.guardian": "오늘 %d/%d 했어요", "progress.elumi": "잘하고 있어요! %d/%d",
      "next": "다음: %@", "streakDays": "%d일 연속", "stars": "별 %d개", "nowCard": "지금 할 일",
      "today.name": "오늘 루미", "today.description": "루미가 오늘 일과를 알려 줘요",
      "nowCard.name": "지금 할 카드", "nowCard.description": "지금 할 카드 한 장을 크게 보여 줘요",
      "streak.name": "별과 연속", "streak.description": "모은 별과 연속 기록을 보여 줘요",
      "lock.name": "오늘 진행", "lock.description": "잠금화면에서 오늘 진행을 봐요",
    ],
    "en": [
      "stale.guardian": "Check today's routines with Lumi?", "stale.elumi": "See today's plan with Lumi?",
      "empty.guardian": "Shall we make a routine today?", "empty.elumi": "Today is a rest day",
      "done.guardian": "All of today's routines are done!", "done.elumi": "All done today! Amazing",
      "night": "Let's do it again tomorrow", "evening": "Lumi is waiting for you",
      "morning.guardian": "Good morning! %d routines today", "morning.elumi": "Good morning! %d things today",
      "ready.guardian": "%d routines are waiting", "ready.elumi": "Ready to start? %d things",
      "progress.guardian": "%d/%d done today", "progress.elumi": "Doing great! %d/%d",
      "next": "Next: %@", "streakDays": "%d-day streak", "stars": "%d stars", "nowCard": "Do now",
      "today.name": "Lumi Today", "today.description": "Lumi shows today's routines",
      "nowCard.name": "Now Card", "nowCard.description": "Shows the card to do now, big",
      "streak.name": "Stars & Streak", "streak.description": "Shows stars and your streak",
      "lock.name": "Today's Progress", "lock.description": "See today's progress on the Lock Screen",
    ],
    "ja": [
      "stale.guardian": "ルミと今日の日課を見ますか？", "stale.elumi": "ルミと今日やることを見よう",
      "empty.guardian": "今日の日課を作ってみませんか？", "empty.elumi": "今日はお休みの日です",
      "done.guardian": "今日の日課はぜんぶ終わりました！", "done.elumi": "今日はぜんぶできた！すごい",
      "night": "また明日いっしょにやろうね", "evening": "ルミが待っています",
      "morning.guardian": "おはよう！今日の日課は%d個", "morning.elumi": "おはよう！今日やることは%d個",
      "ready.guardian": "今日の日課%d個が待っています", "ready.elumi": "はじめてみよう！やること%d個",
      "progress.guardian": "今日 %d/%d できました", "progress.elumi": "いい調子！%d/%d",
      "next": "つぎ：%@", "streakDays": "%d日連続", "stars": "星 %d個", "nowCard": "今やること",
      "today.name": "今日のルミ", "today.description": "ルミが今日の日課を教えてくれます",
      "nowCard.name": "今やるカード", "nowCard.description": "今やるカードを大きく表示します",
      "streak.name": "星と連続", "streak.description": "集めた星と連続記録を表示します",
      "lock.name": "今日の進み", "lock.description": "ロック画面で今日の進みを見られます",
    ],
    "zh": [
      "stale.guardian": "和Lumi一起看看今天的日常？", "stale.elumi": "和Lumi一起看看今天要做的事？",
      "empty.guardian": "今天来做个日常吧？", "empty.elumi": "今天是休息日",
      "done.guardian": "今天的日常都完成了！", "done.elumi": "今天都完成了！真棒",
      "night": "明天再一起做吧", "evening": "Lumi在等你哦",
      "morning.guardian": "早上好！今天有%d个日常", "morning.elumi": "早上好！今天有%d件事",
      "ready.guardian": "%d个日常在等着", "ready.elumi": "开始吧？要做%d件事",
      "progress.guardian": "今天完成了 %d/%d", "progress.elumi": "做得很好！%d/%d",
      "next": "下一个：%@", "streakDays": "连续%d天", "stars": "%d颗星", "nowCard": "现在要做",
      "today.name": "今天的Lumi", "today.description": "Lumi告诉你今天的日常",
      "nowCard.name": "现在的卡片", "nowCard.description": "大大地显示现在要做的卡片",
      "streak.name": "星星和连续", "streak.description": "显示收集的星星和连续记录",
      "lock.name": "今天的进度", "lock.description": "在锁定屏幕上查看今天的进度",
    ],
    "es": [
      "stale.guardian": "¿Vemos las rutinas de hoy con Lumi?", "stale.elumi": "¿Vemos lo de hoy con Lumi?",
      "empty.guardian": "¿Creamos una rutina hoy?", "empty.elumi": "Hoy es día de descanso",
      "done.guardian": "¡Todas las rutinas de hoy hechas!", "done.elumi": "¡Todo hecho hoy! Genial",
      "night": "Mañana lo hacemos otra vez", "evening": "Lumi te está esperando",
      "morning.guardian": "¡Buenos días! %d rutinas hoy", "morning.elumi": "¡Buenos días! %d cosas hoy",
      "ready.guardian": "%d rutinas te esperan", "ready.elumi": "¿Empezamos? %d cosas",
      "progress.guardian": "%d/%d hechas hoy", "progress.elumi": "¡Muy bien! %d/%d",
      "next": "Sigue: %@", "streakDays": "%d días seguidos", "stars": "%d estrellas", "nowCard": "Ahora",
      "today.name": "Lumi de hoy", "today.description": "Lumi te muestra las rutinas de hoy",
      "nowCard.name": "Tarjeta de ahora", "nowCard.description": "Muestra en grande la tarjeta de ahora",
      "streak.name": "Estrellas y racha", "streak.description": "Muestra estrellas y días seguidos",
      "lock.name": "Progreso de hoy", "lock.description": "Mira el progreso de hoy en la pantalla bloqueada",
    ],
  ]

  static func text(_ key: String) -> String {
    let language = Locale.preferredLanguages.first.map { String($0.prefix(2)) } ?? "ko"
    return table[language]?[key] ?? table["ko"]?[key] ?? ""
  }

  /// 루미 한마디: 상태 + 기기(보호자·이룸이) > 문구
  static func message(for entry: ElumWidgetEntry) -> String {
    let device = entry.isElumiDevice ? "elumi" : "guardian"
    let snapshot = entry.snapshot
    let done = snapshot?.doneCount ?? 0
    let total = snapshot?.totalCount ?? 0
    switch entry.mood {
    case .stale: return text("stale.\(device)")
    case .empty: return text("empty.\(device)")
    case .done: return text("done.\(device)")
    case .night: return text("night")
    case .evening: return text("evening")
    case .morning: return String(format: text("morning.\(device)"), total)
    case .ready: return String(format: text("ready.\(device)"), total)
    case .progress: return String(format: text("progress.\(device)"), done, total)
    }
  }
}
