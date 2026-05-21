//
//  FahrtkostenWidgetLiveActivity.swift
//  FahrtkostenWidget
//
//  Created by Thomas Wagner on 12.05.26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct FahrtkostenWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct FahrtkostenWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FahrtkostenWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension FahrtkostenWidgetAttributes {
    fileprivate static var preview: FahrtkostenWidgetAttributes {
        FahrtkostenWidgetAttributes(name: "World")
    }
}

extension FahrtkostenWidgetAttributes.ContentState {
    fileprivate static var smiley: FahrtkostenWidgetAttributes.ContentState {
        FahrtkostenWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: FahrtkostenWidgetAttributes.ContentState {
         FahrtkostenWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: FahrtkostenWidgetAttributes.preview) {
   FahrtkostenWidgetLiveActivity()
} contentStates: {
    FahrtkostenWidgetAttributes.ContentState.smiley
    FahrtkostenWidgetAttributes.ContentState.starEyes
}
