//
//  ContentView.swift
//  A Race of Actors
//
//  Created by Drew McCormack on 05/12/2024.
//

import SwiftUI

struct ContentView: View {
    @State private var lousyResult: Int?
    @State private var forkingResult: Int?
    
    var body: some View {
        VStack(spacing: 20) {
            Button("Run Race") {
                Task {
                    lousyResult = await countTo100(using: LousyContestant())
                    forkingResult = await countTo100(using: ForkingContestant())
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Grid(alignment: .leading, horizontalSpacing: 8) {
                if let lousyResult {
                    GridRow {
                        Text("Lousy Contestant:")
                            .gridColumnAlignment(.trailing)
                        Text("\(lousyResult)")
                    }
                }
                
                if let forkingResult {
                    GridRow {
                        Text("Forking Contestant:")
                            .gridColumnAlignment(.trailing)
                        Text("\(forkingResult)")
                    }
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
