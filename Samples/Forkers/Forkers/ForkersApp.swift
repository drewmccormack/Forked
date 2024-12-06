import SwiftUI

@main
struct ForkersApp: App {
    @State private var store = Store()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
} 