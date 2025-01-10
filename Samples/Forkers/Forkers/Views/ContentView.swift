import SwiftUI

struct ContentView: View {
    @Environment(Store.self) private var store
    @State var editorConfig = EditorConfig()
    
    var body: some View {
        @Bindable var store = store
        NavigationStack {
            List {
                ForEach(store.displayedForkers) { forker in
                    NavigationLink(value: forker.id) {
                        ForkerRow(forker: forker)
                    }
                }
                .onDelete(perform: store.deleteForker)
                .onMove(perform: store.moveForker)
            }
            .overlay {
                if store.displayedForkers.isEmpty {
                    ContentUnavailableView(
                        "No Forkers Yet",
                        systemImage: "person.crop.circle.badge.plus",
                        description: Text("Use the button at the top to add your first Forker.")
                    )
                }
            }
            .navigationDestination(for: Forker.ID.self) { forkerID in
                if let forker = store.displayedForkers.first(where: { $0.id == forkerID}) {
                    ForkerDetailView(forker: forker)
                }
            }
            .navigationTitle("Forkers")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        editorConfig.beginEditing(forker: Forker())
                    }) {
                        Image(systemName: "person.crop.circle.badge.plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                        .disabled(store.displayedForkers.isEmpty)
                }
            }
            .sheet(isPresented: $editorConfig.isEditing) {
                NavigationStack {
                    EditForkerView(forker: $editorConfig.editingForker)
                        .navigationTitle("New Forker")
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Cancel") {
                                    editorConfig.isEditing = false
                                }
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Add") {
                                    store.addForker(editorConfig.editingForker)
                                    editorConfig.isEditing = false
                                }
                                .disabled(!editorConfig.canSave)
                            }
                        }
                }
            }
            .alert("Update Required", isPresented: $store.showUpgradeAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please upgrade to the latest version of the app to continue syncing.")
            }
        }
    }
}
