//
//  Forked_ModelApp.swift
//  Forked Model
//
//  Created by Drew McCormack on 15/11/2024.
//

import SwiftUI

@main
struct ForkedModelApp: App {
    @StateObject private var store = Store()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
