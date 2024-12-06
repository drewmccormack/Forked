import SwiftUI

struct ForkerDetailView: View {
    @Environment(\.dismiss) private var dismiss
    var forker: Forker
    var onSave: ((Forker) -> Void)?
    
    @State private var editedForker: Forker
    
    init(forker: Forker, onSave: ((Forker) -> Void)? = nil) {
        self.forker = forker
        self.onSave = onSave
        self._editedForker = State(initialValue: forker)
    }
    
    var body: some View {
        Form {
            Section("Basic Info") {
                TextField("First Name", text: $editedForker.firstName)
                TextField("Last Name", text: $editedForker.lastName)
                TextField("Company", text: $editedForker.company)
                TextField("Email", text: $editedForker.email)
            }
            
            Section("Additional Info") {
                DatePicker(
                    "Birthday",
                    selection: Binding(
                        get: { editedForker.birthday ?? Date() },
                        set: { editedForker.birthday = $0 }
                    ),
                    displayedComponents: .date
                )
                
                TextField("Notes", text: $editedForker.notes, axis: .vertical)
                    .lineLimit(5...10)
            }
        }
        .navigationTitle(forker.firstName.isEmpty ? "New Forker" : "\(forker.firstName) \(forker.lastName)")
        .toolbar {
            if onSave != nil {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        onSave?(editedForker)
                        dismiss()
                    }
                }
            }
        }
    }
} 