import SwiftUI
import WidgetKit

struct LaunchEntry: TimelineEntry {
    let date: Date
}

struct LaunchProvider: TimelineProvider {
    func placeholder(in context: Context) -> LaunchEntry {
        LaunchEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (LaunchEntry) -> Void) {
        completion(LaunchEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LaunchEntry>) -> Void) {
        completion(Timeline(entries: [LaunchEntry(date: .now)], policy: .never))
    }
}

/// 잠금 화면 앱 실행 위젯. 탭하면 Stargram이 열린다.
struct IManagerAIWidgetView: View {
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image("InterstellarGlyph")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .padding(6)
                .widgetAccentable()
        }
        .unredacted()
        .accessibilityLabel("Stargram 열기")
        .widgetURL(URL(string: "imanagerai://open"))
        .containerBackground(.clear, for: .widget)
    }
}

@main
struct IManagerAIWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.armsone.StarManager.launch.v7", provider: LaunchProvider()) { _ in
            IManagerAIWidgetView()
        }
        .configurationDisplayName("Stargram 열기")
        .description("잠금 화면에서 Stargram을 바로 엽니다.")
        .supportedFamilies([.accessoryCircular])
    }
}
