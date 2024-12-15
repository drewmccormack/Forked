//
//  Forked_ModelApp.swift
//  Forked Model
//
//  Created by Drew McCormack on 15/11/2024.
//

import SwiftUI

@MainActor fileprivate var store = Store()

@main
struct ForkedModelApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
