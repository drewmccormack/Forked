
import SwiftUI

@main
struct ForkingSimpleICloudApp: App {
    @State var store = try! Store()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
