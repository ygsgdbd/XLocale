//
//  XcodeInternationalizationApp.swift
//  XcodeInternationalization
//
//  Created by Rainbow on 2024/12/2.
//

import SwiftUI

@main
struct XLocaleApp: App {
    var body: some Scene {
        WindowGroup {
            XclocEditor()
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
    }
}
