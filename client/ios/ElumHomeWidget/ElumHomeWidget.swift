import SwiftUI
import WidgetKit

// 이룸 홈 화면 위젯 (보호자): 오늘 이룸이 일과 진행 수 · 진행 막대 · 다음 할 일
// 데이터: 앱(Flutter HomeWidgetBridge > HomeWidgetChannel)이 App Group UserDefaults 에 쓴 오늘 요약 JSON
// 요약이 없거나 어제 것이면 "앱을 열어 오늘 일과를 확인해요" (위젯은 네트워크를 쓰지 않음)

/// App Group · 저장 키 (HomeWidgetChannel.swift 와 같은 값)
enum ElumHomeWidgetStore {
  static let appGroupId = "group.kr.twinfang.elum"
  static let snapshotKey = "elum.lockScreenSnapshot"
}

/// 오늘 요약 (Dart LockScreenSnapshot.toJson 중 위젯이 쓰는 키만)
struct ElumRoutineSnapshot: Decodable {
  let dateKey: String
  let doneCount: Int
  let totalCount: Int
  let nextRoutineTitle: String?

  /// 오늘 날짜의 요약인가 (yyyy-MM-dd, 기기 시간대)
  var isToday: Bool {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return dateKey == formatter.string(from: Date())
  }

  static func load() -> ElumRoutineSnapshot? {
    guard
      let json = UserDefaults(suiteName: ElumHomeWidgetStore.appGroupId)?
        .string(forKey: ElumHomeWidgetStore.snapshotKey),
      let data = json.data(using: .utf8)
    else { return nil }
    return try? JSONDecoder().decode(ElumRoutineSnapshot.self, from: data)
  }
}

struct ElumRoutineEntry: TimelineEntry {
  let date: Date
  let snapshot: ElumRoutineSnapshot?
}

/// 타임라인: 지금 요약 1개 + 30분 뒤 다시 읽기 (앱이 요약을 바꾸면 reloadAllTimelines 로 바로 갱신)
struct ElumRoutineProvider: TimelineProvider {
  // 다시 읽는 간격 (자정이 지나면 "앱을 열어 확인" 으로 바뀌게)
  private let refreshInterval: TimeInterval = 30 * 60

  func placeholder(in context: Context) -> ElumRoutineEntry {
    ElumRoutineEntry(
      date: Date(),
      snapshot: ElumRoutineSnapshot(dateKey: "", doneCount: 2, totalCount: 3, nextRoutineTitle: nil)
    )
  }

  func getSnapshot(in context: Context, completion: @escaping (ElumRoutineEntry) -> Void) {
    completion(ElumRoutineEntry(date: Date(), snapshot: ElumRoutineSnapshot.load()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<ElumRoutineEntry>) -> Void) {
    let now = Date()
    let entry = ElumRoutineEntry(date: now, snapshot: ElumRoutineSnapshot.load())
    completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(refreshInterval))))
  }
}

/// 위젯 문구 5개 언어 (기기 언어 > 없으면 한국어). 앱 ARB 의 lockScreen* 문구와 같은 뜻
enum ElumWidgetText {
  private static let table: [String: [String: String]] = [
    "ko": ["title": "오늘 이룸이 일과", "next": "다음 할 일: %@", "allDone": "오늘 일과를 다 끝냈어요",
           "none": "오늘 보낸 일과가 없어요", "stale": "앱을 열어 오늘 일과를 확인해요",
           "name": "오늘 일과", "description": "이룸이가 오늘 일과를 몇 개 했는지 보여 줘요"],
    "en": ["title": "Elumi's routines today", "next": "Next: %@", "allDone": "All of today's routines are done",
           "none": "No routines sent today", "stale": "Open the app to check today's routines",
           "name": "Today's routines", "description": "Shows how many routines Elumi did today"],
    "ja": ["title": "今日のElumiの日課", "next": "次: %@", "allDone": "今日の日課はすべて終わりました",
           "none": "今日送った日課はありません", "stale": "アプリを開いて今日の日課を確認しましょう",
           "name": "今日の日課", "description": "Elumiが今日いくつ日課をやったか表示します"],
    "zh": ["title": "Elumi今天的日常", "next": "下一个: %@", "allDone": "今天的日常都完成了",
           "none": "今天没有发送日常", "stale": "打开应用查看今天的日常",
           "name": "今天的日常", "description": "显示Elumi今天完成了几个日常"],
    "es": ["title": "Rutinas de Elumi hoy", "next": "Siguiente: %@", "allDone": "Las rutinas de hoy están todas hechas",
           "none": "Hoy no se envió ninguna rutina", "stale": "Abre la app para ver las rutinas de hoy",
           "name": "Rutinas de hoy", "description": "Muestra cuántas rutinas hizo Elumi hoy"],
  ]

  static func text(_ key: String) -> String {
    let language = Locale.preferredLanguages.first.map { String($0.prefix(2)) } ?? "ko"
    return table[language]?[key] ?? table["ko"]?[key] ?? ""
  }
}

struct ElumRoutineWidgetView: View {
  let entry: ElumRoutineEntry

  // 앱 토큰과 같은 색: 민트(routineRingProgress) · 트랙 · 진한 글자 · 회색 글자
  private let mint = Color(red: 0x55 / 255, green: 0xCF / 255, blue: 0xBA / 255)
  private let track = Color(red: 0xEE / 255, green: 0xE9 / 255, blue: 0xE6 / 255)
  private let primaryText = Color(red: 0x1A / 255, green: 0x24 / 255, blue: 0x2B / 255)
  private let secondaryText = Color(red: 0x74 / 255, green: 0x75 / 255, blue: 0x7D / 255)

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(ElumWidgetText.text("title"))
        .font(.system(size: 13, weight: .semibold))
        .foregroundColor(secondaryText)
      if let snapshot = entry.snapshot, snapshot.isToday, snapshot.totalCount > 0 {
        Text("\(snapshot.doneCount)/\(snapshot.totalCount)")
          .font(.system(size: 30, weight: .heavy))
          .foregroundColor(primaryText)
        progressBar(done: snapshot.doneCount, total: snapshot.totalCount)
        Text(message(for: snapshot))
          .font(.system(size: 13, weight: .medium))
          .foregroundColor(primaryText)
          .lineLimit(2)
      } else {
        Spacer(minLength: 0)
        Text(entry.snapshot?.isToday == true ? ElumWidgetText.text("none") : ElumWidgetText.text("stale"))
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(primaryText)
          .lineLimit(3)
      }
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .widgetBackground(Color.white)
  }

  private func message(for snapshot: ElumRoutineSnapshot) -> String {
    if snapshot.doneCount >= snapshot.totalCount { return ElumWidgetText.text("allDone") }
    guard let next = snapshot.nextRoutineTitle else { return "" }
    return String(format: ElumWidgetText.text("next"), next)
  }

  private func progressBar(done: Int, total: Int) -> some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule().fill(track)
        Capsule().fill(mint)
          .frame(width: geometry.size.width * CGFloat(done) / CGFloat(max(total, 1)))
      }
    }
    .frame(height: 8)
  }
}

private extension View {
  /// iOS 17+ 위젯 배경 (그 아래는 일반 배경)
  @ViewBuilder
  func widgetBackground(_ color: Color) -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      containerBackground(color, for: .widget)
    } else {
      padding().background(color)
    }
  }
}

@main
struct ElumHomeWidget: Widget {
  private let kind = "ElumHomeWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: ElumRoutineProvider()) { entry in
      ElumRoutineWidgetView(entry: entry)
    }
    .configurationDisplayName(ElumWidgetText.text("name"))
    .description(ElumWidgetText.text("description"))
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
