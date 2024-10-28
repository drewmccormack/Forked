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
            Text("Enter a message to store in iCloud")
                .foregroundStyle(.secondary)
                .font(.headline)
            TextField("Message", text: $store.displayedText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
