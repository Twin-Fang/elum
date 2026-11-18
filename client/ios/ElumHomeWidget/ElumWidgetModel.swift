import Foundation
import WidgetKit

// 루미 위젯 데이터: 오늘 요약 읽기 > 루미 상태 > 문구 (#1465)
// 상태 규칙 단일 원본: docs/superpowers/specs/2026-11-18-lumi-widgets-design.md (Android ElumWidgetState.kt 와 같은 규칙)

/// App Group · 저장 키 (Runner HomeWidgetChannel.swift 와 같은 값)
enum ElumWidgetStore {
  static let appGroupId = "group.kr.twinfang.elum"
  static let snapshotKey = "elum.lockScreenSnapshot"
}

/// 이룸이 지금 할 카드 (요약 JSON elumiCard 중 위젯이 쓰는 키만)
struct ElumWidgetCard: Decodable {
  let routineId: String
  let routineTitle: String?
  let cardText: String?
  let imageFilePath: String?
}

/// 오늘 요약 (Dart LockScreenSnapshot.toJson 중 위젯이 쓰는 키만, 없는 키는 기본값)
struct ElumWidgetSnapshot: Decodable {
  let mode: String
  let dateKey: String
  let doneCount: Int
  let totalCount: Int
  let nextRoutineTitle: String?
  let elumiCard: ElumWidgetCard?
  let elumiName: String?
  let streakDays: Int
  let starCount: Int

  enum CodingKeys: String, CodingKey {
    case mode, dateKey, doneCount, totalCount, nextRoutineTitle, elumiCard, elumiName, streakDays, starCount
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    mode = (try? container.decode(String.self, forKey: .mode)) ?? "guardian"
    dateKey = try container.decode(String.self, forKey: .dateKey)
    doneCount = (try? container.decode(Int.self, forKey: .doneCount)) ?? 0
    totalCount = (try? container.decode(Int.self, forKey: .totalCount)) ?? 0
    nextRoutineTitle = try? container.decodeIfPresent(String.self, forKey: .nextRoutineTitle)
    elumiCard = try? container.decodeIfPresent(ElumWidgetCard.self, forKey: .elumiCard)
    elumiName = try? container.decodeIfPresent(String.self, forKey: .elumiName)
    streakDays = (try? container.decode(Int.self, forKey: .streakDays)) ?? 0
    starCount = (try? container.decode(Int.self, forKey: .starCount)) ?? 0
  }

  var isElumiDevice: Bool { mode == "elumi" }

  /// 오늘 날짜의 요약인가 (yyyy-MM-dd, 기기 시간대)
  func isFresh(on date: Date) -> Bool {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return dateKey == formatter.string(from: date)
  }

  static func load() -> ElumWidgetSnapshot? {
    guard
      let json = UserDefaults(suiteName: ElumWidgetStore.appGroupId)?.string(forKey: ElumWidgetStore.snapshotKey),
      let data = json.data(using: .utf8)
    else { return nil }
    return try? JSONDecoder().decode(ElumWidgetSnapshot.self, from: data)
  }
}

/// 루미 상태 8가지 (위에서부터 먼저 맞는 것)
enum LumiMood {
  case stale, empty, done, night, evening, morning, ready, progress

  // 시간대 경계 (기기 시각): 아침 < 12 · 저녁 >= 18 · 밤 >= 21
  private static let morningEndHour = 12
  private static let eveningStartHour = 18
  private static let nightStartHour = 21

  static func of(_ snapshot: ElumWidgetSnapshot?, at date: Date) -> LumiMood {
    guard let snapshot = snapshot, snapshot.isFresh(on: date) else { return .stale }
    if snapshot.totalCount == 0 { return .empty }
    if snapshot.doneCount >= snapshot.totalCount { return .done }
    let hour = Calendar.current.component(.hour, from: date)
    if hour >= nightStartHour { return .night }
    if snapshot.doneCount == 0 {
      if hour >= eveningStartHour { return .evening }
      if hour < morningEndHour { return .morning }
      return .ready
    }
    return .progress
  }

  /// 상태 > 루미 그림 (위젯 Assets.xcassets 이름)
  func imageName(isElumiDevice: Bool) -> String {
    switch self {
    case .stale, .morning: return "lumi_hello"
    case .empty: return isElumiDevice ? "lumi_resting" : "lumi_new_routine"
    case .done: return "lumi_celebrate_star"
    case .night: return "lumi_sleepy"
    case .evening: return "lumi_waiting"
    case .ready: return "lumi_holding_card"
    case .progress: return "lumi_cheer"
    }
  }
}

/// 다음에 다시 그릴 시각: 30분 뒤 또는 다음 시간대 경계 중 이른 것 (아침 > 낮 > 저녁 > 밤 표정이 제때 바뀌게)
enum ElumWidgetRefresh {
  private static let maximumInterval: TimeInterval = 30 * 60
  private static let boundaryHours = [0, 12, 18, 21]

  static func nextDate(after date: Date) -> Date {
    let calendar = Calendar.current
    let latest = date.addingTimeInterval(maximumInterval)
    let boundaries = boundaryHours.compactMap { hour in
      calendar.nextDate(after: date, matching: DateComponents(hour: hour, minute: 0), matchingPolicy: .nextTime)
    }
    return ([latest] + boundaries).min() ?? latest
  }
}

/// 타임라인 항목: 시각 + 요약 (상태는 그릴 때 시각으로 계산)
struct ElumWidgetEntry: TimelineEntry {
  let date: Date
  let snapshot: ElumWidgetSnapshot?

  var mood: LumiMood { LumiMood.of(snapshot, at: date) }
  var isElumiDevice: Bool { snapshot?.isElumiDevice ?? false }
}

/// 위젯 3종 공통 타임라인: 지금 요약 1개 > 다음 경계 시각에 다시 읽기 (앱이 요약을 바꾸면 바로 새로 그림)
struct ElumWidgetProvider: TimelineProvider {
  func placeholder(in context: Context) -> ElumWidgetEntry {
    ElumWidgetEntry(date: Date(), snapshot: nil)
  }

  func getSnapshot(in context: Context, completion: @escaping (ElumWidgetEntry) -> Void) {
    completion(ElumWidgetEntry(date: Date(), snapshot: ElumWidgetSnapshot.load()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<ElumWidgetEntry>) -> Void) {
    let now = Date()
    let entry = ElumWidgetEntry(date: now, snapshot: ElumWidgetSnapshot.load())
    completion(Timeline(entries: [entry], policy: .after(ElumWidgetRefresh.nextDate(after: now))))
  }
}

/// 위젯 > 앱 경로 URL (Runner HomeWidgetChannel.open 이 받음, 값은 Android 잠금화면 경로와 같음)
enum ElumWidgetRoute {
  static func url(routineId: String? = nil) -> URL {
    let route = routineId.map { "routine:\($0)" } ?? "home"
    var components = URLComponents()
    components.scheme = "elum"
    components.host = "widget"
    components.queryItems = [URLQueryItem(name: "route", value: route)]
    return components.url ?? URL(string: "elum://widget?route=home")!
  }
}
