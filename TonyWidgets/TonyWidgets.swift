import SwiftUI
import TonyCore
import TonyStore
import WidgetKit

@main
struct TonyWidgets: WidgetBundle {
    var body: some Widget {
        PlaceholderWidget()
    }
}

/// Stands in until the real widgets land (C20), so the extension builds and embeds.
struct PlaceholderWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PlaceholderWidget", provider: PlaceholderProvider()) { _ in
            Text("Tony")
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Tony")
        .description("Your day at a glance.")
        .supportedFamilies([.systemSmall])
    }
}

struct PlaceholderEntry: TimelineEntry {
    let date: Date
    var taskCount = 0
}

struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlaceholderEntry {
        PlaceholderEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (PlaceholderEntry) -> Void) {
        completion(PlaceholderEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<PlaceholderEntry>) -> Void) {
        Task {
            let tasks = try? await SwiftDataRepository.appGroup().tasks()
            let entry = PlaceholderEntry(date: .now, taskCount: tasks?.count ?? 0)
            completion(Timeline(entries: [entry], policy: .never))
        }
    }
}
