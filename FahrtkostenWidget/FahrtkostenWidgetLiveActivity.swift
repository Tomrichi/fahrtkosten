import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Activity Attributes
// WICHTIG: Diese Struct muss denselben activityType-String haben wie in LiveActivityManager.swift
struct FahrtkostenWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var km: Double
        var elapsedSeconds: Int
        var speedKmh: Double
    }
    var startedAt: Date

    // Gemeinsamer Identifier damit App & Widget-Extension zusammenpassen
    static var activityType: String { "de.tommwagner.fahrtkosten.gpstrip" }
}

// MARK: - Live Activity Widget
struct FahrtkostenWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FahrtkostenWidgetAttributes.self) { context in

            // ── Lock Screen / Notification Banner ──
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "car.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 20))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("GPS Fahrt läuft")
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    HStack(spacing: 12) {
                        Label(String(format: "%.1f km", context.state.km),
                              systemImage: "road.lanes")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Label(elapsedString(context.state.elapsedSeconds),
                              systemImage: "timer")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if context.state.speedKmh > 2 {
                            Label(String(format: "%.0f km/h", context.state.speedKmh),
                                  systemImage: "speedometer")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .activityBackgroundTint(Color(.systemBackground))

        } dynamicIsland: { context in
            DynamicIsland {

                // ── Expanded ──
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Image(systemName: "road.lanes")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text(String(format: "%.1f", context.state.km))
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange)
                            .minimumScaleFactor(0.7)
                        Text("km")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Image(systemName: "timer")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(elapsedString(context.state.elapsedSeconds))
                            .font(.system(size: 18, weight: .semibold, design: .monospaced))
                            .foregroundColor(.primary)
                            .minimumScaleFactor(0.7)
                        Text("Zeit")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.trailing, 4)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Image(systemName: "car.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("Fahrt aktiv")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        if context.state.speedKmh > 2 {
                            Label(String(format: "%.0f km/h", context.state.speedKmh),
                                  systemImage: "speedometer")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.bottom, 4)
                }

            } compactLeading: {
                // Kleines Auto + km
                HStack(spacing: 3) {
                    Image(systemName: "car.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 11))
                    Text(String(format: "%.1f", context.state.km))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.orange)
                }

            } compactTrailing: {
                // Zeit
                Text(elapsedString(context.state.elapsedSeconds))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary)

            } minimal: {
                Image(systemName: "car.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 14))
            }
            .widgetURL(URL(string: "fahrtkosten://gps"))
            .keylineTint(.orange)
        }
    }

    private func elapsedString(_ secs: Int) -> String {
        let h = secs / 3600
        let m = (secs % 3600) / 60
        let s = secs % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}

// MARK: - Previews
extension FahrtkostenWidgetAttributes {
    fileprivate static var preview: FahrtkostenWidgetAttributes {
        FahrtkostenWidgetAttributes(startedAt: Date())
    }
}
extension FahrtkostenWidgetAttributes.ContentState {
    fileprivate static var driving: FahrtkostenWidgetAttributes.ContentState {
        .init(km: 14.3, elapsedSeconds: 1945, speedKmh: 72)
    }
    fileprivate static var start: FahrtkostenWidgetAttributes.ContentState {
        .init(km: 0.0, elapsedSeconds: 0, speedKmh: 0)
    }
}

#Preview("Notification", as: .content, using: FahrtkostenWidgetAttributes.preview) {
    FahrtkostenWidgetLiveActivity()
} contentStates: {
    FahrtkostenWidgetAttributes.ContentState.start
    FahrtkostenWidgetAttributes.ContentState.driving
}
