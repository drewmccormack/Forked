//
//  ContentView.swift
//  Forking Simple iCloud
//
//  Created by Drew McCormack on 24/10/2024.
//

import SwiftUI

struct ContentView: View {
    @Environment(Store.self) var store
    
    var body: some View {
        @Bindable var store = store
        VStack(alignment: .center) {
            Text("Message in iCloud")
                .font(.title2)
                .multilineTextAlignment(.center)
                .opacity(0.6)
            TextField("Message", text: $store.displayedText)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
