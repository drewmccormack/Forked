import SwiftUI

@main
struct ForkersApp: App {
    @Environment(\.scenePhase) var scenePhase
    @State private var store = try! Store()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
        .onChange(of: scenePhase) {
            if scenePhase == .background {
                store.save()
            }
        }
    }
} 
