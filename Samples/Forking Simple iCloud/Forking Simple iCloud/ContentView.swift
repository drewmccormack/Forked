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
        VStack {
            TextField("Message", text: $store.displayedText)
        }
        .padding()
    }
}
