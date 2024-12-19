import SwiftUI

struct ForkerDetailView: View {
    @Environment(Store.self) private var store
    @State private var editorConfig = EditorConfig()
    let forker: Forker
    
    var body: some View {
        Form {
            Section("Basic Info") {
                LabeledContent("First Name", value: forker.firstName)
                LabeledContent("Last Name", value: forker.lastName)
                if !forker.company.isEmpty {
                    LabeledContent("Company", value: forker.company)
                }
                if !forker.email.isEmpty {
                    LabeledContent("Email", value: forker.email)
                }
            }
            
            Section("Additional Info") {
                
                if let birthday = forker.birthday {
                    LabeledContent("Birthday") {
                        Text(birthday, style: .date)
                    }
                }
                
                if forker.balance.dollarAmount != 0 {
                    LabeledContent("Owes Me") {
                        Text(forker.balance.dollarAmount, format: .currency(code: "USD"))
                            .foregroundStyle(forker.balance.dollarAmount < 0 ? .red : .green)
                    }
                }
                
                if let category = forker.category {
                    LabeledContent("Category") {
                        Label(category.rawValue.capitalized, systemImage: category.systemImage)
                    }
                }
                
                if let color = forker.color {
                    LabeledContent("Color") {
                        Label(color.rawValue.capitalized, systemImage: "circle.fill")
                            .foregroundStyle(color.color)
                    }
                }
                
                if !forker.tags.isEmpty {
                    LabeledContent("Tags") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(Array(forker.tags).sorted(), id: \.self) { tag in
                                    Text(tag)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.secondary.opacity(0.2))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }
                }
                if !forker.notes.isEmpty {
                    LabeledContent("Notes", value: forker.notes)
                }
            }
        }
        .overlay {
            if editorConfig.isEditing {
                EditForkerView(forker: $editorConfig.editingForker)
            }
        }
        .animation(.default, value: editorConfig.isEditing)
        .navigationTitle("\(forker.firstName) \(forker.lastName)")
        .navigationBarBackButtonHidden(editorConfig.isEditing)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if editorConfig.isEditing {
                    Button("Save") {
                        store.updateEditingForker(editorConfig.editingForker)
                        editorConfig.isEditing = false
                    }
                    .disabled(!editorConfig.canSave)
                } else {
                    Button("Edit") {
                        store.prepareToEditForker()
                        let editingForker = store.editingForker(withId: forker.id)!
                        editorConfig.beginEditing(forker: editingForker)
                    }
                }
            }
            if editorConfig.isEditing {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        editorConfig.isEditing = false
                    }
                }
            }
        }
    }
}
