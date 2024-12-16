import SwiftUI

@main
struct ForkedModelApp: App {
    @State var store = Store()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
