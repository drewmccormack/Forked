
import SwiftUI

@main
struct ForkingSimpleICloudApp: App {
    @Environment(\.scenePhase) var scenePhase
    @State var store = try! Store()
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
