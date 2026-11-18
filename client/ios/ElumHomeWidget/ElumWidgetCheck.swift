import AppIntents
import Foundation
import WidgetKit

// 위젯에서 카드 체크 (#1465 2단계): 대기열 · 표시 상태 · "다 했어요" AppIntent(iOS 17+)
// 약속: docs/superpowers/specs/2026-11-18-widget-card-check-design.md 「구현 약속」 (Android ElumWidgetCheckReceiver 와 같은 키)

/// 위젯 체크 저장소 (App Group UserDefaults, 앱 HomeWidgetChannel 이 대기열을 꺼내 감)
enum ElumWidgetCheckStore {
  static let outboxKey = "elum.widget.checkOutbox"
  static let checkedCardIdsKey = "elum.widget.checkedCardIds"
  static let lastCheckAtKey = "elum.widget.lastCheckAtMillis"

  // 연속 누름 막기 (같은 손가락이 다음 카드까지 끝내지 않게) · 체크 뒤 칭찬을 보여 줄 시간
  static let debounceMilliseconds: Double = 1500
  static let praiseDurationMilliseconds: Double = 10 * 60 * 1000

  private static var defaults: UserDefaults? { UserDefaults(suiteName: ElumWidgetStore.appGroupId) }

  /// 위젯이 표시용으로 넘긴 카드 id (앱이 새 요약을 보내면 비워짐)
  static var checkedCardIds: [String] {
    guard let json = defaults?.string(forKey: checkedCardIdsKey), let data = json.data(using: .utf8),
          let ids = try? JSONDecoder().decode([String].self, from: data)
    else { return [] }
    return ids
  }

  static var lastCheckAtMillis: Double { defaults?.double(forKey: lastCheckAtKey) ?? 0 }

  /// 방금 체크했는가 (칭찬 루미를 보일 때)
  static func isRecentlyChecked(at date: Date) -> Bool {
    let elapsed = date.timeIntervalSince1970 * 1000 - lastCheckAtMillis
    return lastCheckAtMillis > 0 && elapsed >= 0 && elapsed < praiseDurationMilliseconds
  }

  /// 체크 1건 기록: 연속 누름이면 무시 > 대기열(중복 없이) + 표시 상태 + 시각 > true
  static func record(routineId: String, cardId: String, dateKey: String, now: Date = Date()) -> Bool {
    guard let defaults = defaults else { return false }
    let nowMillis = now.timeIntervalSince1970 * 1000
    if nowMillis - lastCheckAtMillis < debounceMilliseconds { return false }
    var outbox = readOutbox(defaults)
    if !outbox.contains(where: { $0["routineId"] as? String == routineId && $0["cardId"] as? String == cardId }) {
      outbox.append(["routineId": routineId, "cardId": cardId, "dateKey": dateKey, "checkedAtMillis": Int64(nowMillis)])
    }
    write(outbox, key: outboxKey, defaults: defaults)
    var ids = checkedCardIds
    if !ids.contains(cardId) { ids.append(cardId) }
    write(ids, key: checkedCardIdsKey, defaults: defaults)
    defaults.set(nowMillis, forKey: lastCheckAtKey)
    return true
  }

  // 깨진 대기열은 비우고 새로 시작 (위젯은 요약 기준으로 돌아감)
  private static func readOutbox(_ defaults: UserDefaults) -> [[String: Any]] {
    guard let json = defaults.string(forKey: outboxKey), let data = json.data(using: .utf8) else { return [] }
    guard let items = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else {
      NSLog("[widget check] outbox corrupt, cleared")
      defaults.removeObject(forKey: outboxKey)
      return []
    }
    return items
  }

  private static func write(_ object: Any, key: String, defaults: UserDefaults) {
    guard let data = try? JSONSerialization.data(withJSONObject: object),
          let json = String(data: data, encoding: .utf8)
    else { return }
    defaults.set(json, forKey: key)
  }
}

/// 위젯이 지금 보여 줄 카드 한 장 (지금 카드 · 다음 카드 공통 모양)
struct ElumWidgetShownCard {
  let cardId: String
  let cardText: String
  let imageFilePath: String?
}

/// 위젯 체크 동작 4가지: 대기열에 넣기 · 앱 열어 체크(마지막 카드) · 앱에서 이어서(받아 둔 카드 소진) · 없음
enum ElumWidgetCheckMode {
  case queue(ElumWidgetShownCard)
  case openAppToCheck(ElumWidgetShownCard)
  case continueInApp
  case none
}

extension ElumWidgetEntry {
  /// 이룸이 기기 · 오늘 요약일 때 보여 줄 카드와 체크 동작 (위젯이 넘긴 카드는 건너뜀)
  var checkMode: ElumWidgetCheckMode {
    guard isElumiDevice, mood != .stale, let card = snapshot?.elumiCard else { return .none }
    let checked = Set(ElumWidgetCheckStore.checkedCardIds)
    let candidates = [ElumWidgetShownCard(cardId: card.cardId, cardText: card.cardText ?? "", imageFilePath: card.imageFilePath)]
      + (card.upcomingCards ?? []).map {
        ElumWidgetShownCard(cardId: $0.cardId, cardText: $0.cardText ?? "", imageFilePath: $0.imageFilePath)
      }
    let remaining = (card.remainingCount ?? 1) - checked.count
    guard let shown = candidates.first(where: { !checked.contains($0.cardId) }), remaining > 0 else {
      return checked.isEmpty ? .none : .continueInApp
    }
    return remaining >= 2 ? .queue(shown) : .openAppToCheck(shown)
  }
}

/// 「다 했어요」 (iOS 17+ 위젯 버튼): 앱을 열지 않고 체크 > 위젯 새로 그림 (다음 카드 · 칭찬 루미)
@available(iOSApplicationExtension 17.0, *)
struct ElumCheckCardIntent: AppIntent {
  static var title: LocalizedStringResource = "Check card"
  // 단축어 앱 등 위젯 밖에는 내보내지 않음
  static var isDiscoverable: Bool = false

  @Parameter(title: "Routine") var routineId: String
  @Parameter(title: "Card") var cardId: String
  @Parameter(title: "Date") var dateKey: String

  init() {}

  init(routineId: String, cardId: String, dateKey: String) {
    self.routineId = routineId
    self.cardId = cardId
    self.dateKey = dateKey
  }

  func perform() async throws -> some IntentResult {
    if ElumWidgetCheckStore.record(routineId: routineId, cardId: cardId, dateKey: dateKey) {
      WidgetCenter.shared.reloadAllTimelines()
    }
    return .result()
  }
}
