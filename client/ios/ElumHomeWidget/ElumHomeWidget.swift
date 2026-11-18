import SwiftUI
import WidgetKit

// 이룸 위젯 묶음 (#1410, #1465): 홈 화면 5종(오늘 루미 · 지금 할 카드 · 별과 연속 · 오늘 일과 목록 · 빠른 만들기) + 잠금화면 1종
// 데이터: 앱이 App Group 에 쓴 오늘 요약 JSON (ElumWidgetModel.swift) · 위젯은 네트워크를 쓰지 않음
// 누르면 elum://widget?route=... > 앱이 그 화면을 엶 (Runner HomeWidgetChannel)

@main
struct ElumWidgetBundle: WidgetBundle {
  var body: some Widget {
    ElumTodayWidget()
    ElumNowCardWidget()
    ElumStreakWidget()
    ElumRoutineListWidget()
    ElumQuickCreateWidget()
    ElumLockScreenWidget()
  }
}

/// 「오늘 일과 목록」: 오늘 일과 줄마다 진행 · 줄을 누르면 그 일과(이룸이 기기) · 그 밖은 홈 (#1465)
struct ElumRoutineListWidget: Widget {
  private let kind = "ElumRoutineListWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: ElumWidgetProvider()) { entry in
      ElumWidgetPanel { family in
        ElumRoutineListView(entry: entry, family: family)
      }
      .widgetURL(ElumWidgetRoute.url())
    }
    .configurationDisplayName(ElumWidgetText.text("list.name"))
    .description(ElumWidgetText.text("list.description"))
    .supportedFamilies([.systemMedium, .systemLarge])
  }
}

/// 「빠른 만들기」: 누르면 일과 만들기 시작 (이룸이 기기는 홈)
struct ElumQuickCreateWidget: Widget {
  private let kind = "ElumQuickCreateWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: ElumWidgetProvider()) { _ in
      ElumWidgetPanel { _ in
        ElumQuickCreateView()
      }
      .widgetURL(ElumWidgetRoute.createURL())
    }
    .configurationDisplayName(ElumWidgetText.text("create.name"))
    .description(ElumWidgetText.text("create.description"))
    .supportedFamilies([.systemSmall])
  }
}

/// 「오늘 루미」: 루미 표정 + 한마디 + 진행 (보호자 · 이룸이 기기 공통) · 누르면 홈
struct ElumTodayWidget: Widget {
  // kind 는 바꾸지 않음 (#1410 에서 이미 놓은 위젯이 그대로 이어지게)
  private let kind = "ElumHomeWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: ElumWidgetProvider()) { entry in
      ElumWidgetPanel { family in
        ElumTodayView(entry: entry, isMedium: family == .systemMedium)
      }
      .widgetURL(ElumWidgetRoute.url())
    }
    .configurationDisplayName(ElumWidgetText.text("today.name"))
    .description(ElumWidgetText.text("today.description"))
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

/// 「지금 할 카드」: 이룸이가 지금 할 카드 한 장 (없으면 오늘 루미) · 누르면 그 일과 카드
struct ElumNowCardWidget: Widget {
  private let kind = "ElumNowCardWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: ElumWidgetProvider()) { entry in
      ElumWidgetPanel { family in
        ElumNowCardView(entry: entry, family: family)
      }
      .widgetURL(ElumWidgetRoute.url(routineId: entry.snapshot?.elumiCard?.routineId))
    }
    .configurationDisplayName(ElumWidgetText.text("nowCard.name"))
    .description(ElumWidgetText.text("nowCard.description"))
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}

/// 「별과 연속」: 모은 별 + 연속 기록 · 누르면 홈
struct ElumStreakWidget: Widget {
  private let kind = "ElumStreakWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: ElumWidgetProvider()) { entry in
      ElumWidgetPanel { _ in
        ElumStreakView(entry: entry)
      }
      .widgetURL(ElumWidgetRoute.url())
    }
    .configurationDisplayName(ElumWidgetText.text("streak.name"))
    .description(ElumWidgetText.text("streak.description"))
    .supportedFamilies([.systemSmall])
  }
}

/// 잠금화면 「오늘 진행」 (iOS 16+): 원형 링 · 직사각형 · 한 줄
struct ElumLockScreenWidget: Widget {
  private let kind = "ElumLockScreenWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: ElumWidgetProvider()) { entry in
      ElumLockScreenFamilyView(entry: entry)
        .widgetURL(ElumWidgetRoute.url())
    }
    .configurationDisplayName(ElumWidgetText.text("lock.name"))
    .description(ElumWidgetText.text("lock.description"))
    .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
  }
}

/// 잠금화면 위젯: 지금 크기를 읽어 본문에 넘김 (잠금화면은 시스템 배경)
private struct ElumLockScreenFamilyView: View {
  let entry: ElumWidgetEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    ElumLockScreenView(entry: entry, family: family)
      .elumAccessoryBackground()
  }
}

/// 홈 화면 위젯 판: 다크모드에 맞는 판 색 + 지금 크기를 본문에 넘김
private struct ElumWidgetPanel<Content: View>: View {
  let content: (WidgetFamily) -> Content
  @Environment(\.widgetFamily) private var family
  @Environment(\.colorScheme) private var scheme

  init(@ViewBuilder content: @escaping (WidgetFamily) -> Content) {
    self.content = content
  }

  var body: some View {
    content(family)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .elumWidgetBackground(ElumWidgetColor.panel(scheme))
  }
}

private extension View {
  /// 잠금화면 위젯 배경 (iOS 17+ 는 containerBackground 필수)
  @ViewBuilder
  func elumAccessoryBackground() -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      containerBackground(.clear, for: .widget)
    } else {
      self
    }
  }
}
