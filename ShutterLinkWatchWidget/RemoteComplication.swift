//
//  RemoteComplication.swift
//  ShutterLinkWatchWidget
//
//  시계 화면의 셔터 단추 — 누르면 바로 리모컨(워치 앱)이 열린다. 보여 줄 값은 없다, 들어가는 문이다.
//

import WidgetKit
import SwiftUI

struct RemoteEntry: TimelineEntry {
    let date: Date
}

struct RemoteProvider: TimelineProvider {
    func placeholder(in context: Context) -> RemoteEntry { RemoteEntry(date: .now) }

    func getSnapshot(in context: Context, completion: @escaping (RemoteEntry) -> Void) {
        completion(RemoteEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RemoteEntry>) -> Void) {
        completion(Timeline(entries: [RemoteEntry(date: .now)], policy: .never))
    }
}

struct RemoteComplicationView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "camera.shutter.button")
                    .font(.title2)
                    .widgetAccentable()
            }
        case .accessoryCorner:
            Image(systemName: "camera.shutter.button")
                .font(.title2)
                .widgetAccentable()
                .widgetLabel { Text(verbatim: "ShutterLink") }
        case .accessoryInline:
            Label { Text(verbatim: "ShutterLink") } icon: { Image(systemName: "camera.shutter.button") }
        default:
            VStack(alignment: .leading, spacing: 2) {
                Label { Text(verbatim: "ShutterLink") } icon: { Image(systemName: "camera.shutter.button") }
                    .font(.headline)
                    .widgetAccentable()
                Text("Tap to shoot from your wrist")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

@main
struct RemoteComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ShutterRemote", provider: RemoteProvider()) { _ in
            RemoteComplicationView()
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Shutter Remote")
        .description("Opens the remote. Your iPhone takes the photo.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}
