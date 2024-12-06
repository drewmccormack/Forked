import SwiftUI

struct ContentView: View {
    @Environment(Store.self) private var store
    @State private var showingAddForker = false
    
    var body: some View {
        NavigationStack {
            Group {
                if store.forkers.isEmpty {
                    ContentUnavailableView(
                        "No Forkers Yet",
                        systemImage: "person.crop.circle.badge.plus",
                        description: Text("Use the button at the top to add your first Forker.")
                    )
                } else {
                    List {
                        ForEach(store.forkers) { forker in
                            NavigationLink(value: forker) {
                                ForkerRow(forker: forker)
                            }
                        }
                        .onDelete(perform: store.deleteForker)
                        .onMove(perform: store.moveForker)
                    }
                }
            }
            .navigationTitle("Forkers")
            .navigationDestination(for: Forker.self) { forker in
                ForkerDetailView(forker: forker)
                    .environment(store)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAddForker = true }) {
                        Image(systemName: "person.crop.circle.badge.plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                        .disabled(store.forkers.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showingAddForker) {
            NavigationStack {
                ForkerDetailView(forker: Forker()) { newForker in
                    store.addForker(newForker)
                }
            }
        }
    }
} 