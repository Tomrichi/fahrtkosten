//
//  FahrtkostenWatchApp.swift
//  FahrtkostenWatch Watch App
//
//  Created by Thomas Wagner on 13.05.26.
//

import SwiftUI

@main
struct FahrtkostenWatch_Watch_AppApp: App {
    @StateObject private var model = WatchViewModel()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(model)
        }
    }
}
