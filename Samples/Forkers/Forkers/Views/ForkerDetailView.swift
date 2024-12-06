import SwiftUI

struct ForkerDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(Store.self) private var store
    let forker: Forker
    var onSave: ((Forker) -> Void)?
    
    @State private var editedForker: Forker
    @State private var isEditing = false
    
    private var isValid: Bool {
        !editedForker.firstName.isEmpty || !editedForker.lastName.isEmpty
    }
    
    init(forker: Forker, onSave: ((Forker) -> Void)? = nil) {
        self.forker = forker
        self.onSave = onSave
        self._editedForker = State(initialValue: forker)
        self._isEditing = State(initialValue: onSave != nil)
    }
    
    var body: some View {
        Form {
            Section("Basic Info") {
                if isEditing {
                    TextField("First Name", text: $editedForker.firstName)
                    TextField("Last Name", text: $editedForker.lastName)
                    TextField("Company", text: $editedForker.company)
                    TextField("Email", text: $editedForker.email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                } else {
                    LabeledContent("First Name", value: editedForker.firstName)
                    LabeledContent("Last Name", value: editedForker.lastName)
                    if !editedForker.company.isEmpty {
                        LabeledContent("Company", value: editedForker.company)
                    }
                    if !editedForker.email.isEmpty {
                        LabeledContent("Email", value: editedForker.email)
                    }
                }
            }
            
            Section("Additional Info") {
                if isEditing {
                    DatePicker(
                        "Birthday",
                        selection: Binding(
                            get: { editedForker.birthday ?? Date() },
                            set: { editedForker.birthday = $0 }
                        ),
                        displayedComponents: .date
                    )
                    
                    Picker("Category", selection: $editedForker.category) {
                        Text("None")
                            .tag(Optional<ForkerCategory>.none)
                        ForEach(ForkerCategory.allCases, id: \.self) { category in
                            Label(category.rawValue.capitalized, systemImage: category.systemImage)
                                .tag(Optional(category))
                        }
                    }
                    .pickerStyle(.navigationLink)
                    
                    Picker("Color", selection: $editedForker.color) {
                        Text("None")
                            .tag(Optional<ForkerColor>.none)
                        ForEach(ForkerColor.allCases, id: \.self) { color in
                            Label(color.rawValue.capitalized, systemImage: "circle.fill")
                                .foregroundStyle(color.color)
                                .tag(Optional(color))
                        }
                    }
                    .pickerStyle(.navigationLink)
                    
                    TextField("Notes", text: $editedForker.notes, axis: .vertical)
                        .lineLimit(5...10)
                } else {
                    if let birthday = editedForker.birthday {
                        LabeledContent("Birthday") {
                            Text(birthday, style: .date)
                        }
                    }
                    if let category = editedForker.category {
                        LabeledContent("Category") {
                            Label(category.rawValue.capitalized, systemImage: category.systemImage)
                        }
                    }
                    if let color = editedForker.color {
                        LabeledContent("Color") {
                            Label(color.rawValue.capitalized, systemImage: "circle.fill")
                                .foregroundStyle(color.color)
                        }
                    }
                    if !editedForker.notes.isEmpty {
                        LabeledContent("Notes", value: editedForker.notes)
                    }
                }
            }
        }
        .navigationTitle(editedForker.firstName.isEmpty ? "New Forker" : "\(editedForker.firstName) \(editedForker.lastName)")
        .navigationBarBackButtonHidden(isEditing)
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
                    .disabled(!isValid)
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    if isEditing {
                        Button("Save") {
                            store.updateForker(editedForker)
                            isEditing = false
                        }
                        .disabled(!isValid)
                    } else {
                        Button("Edit") {
                            isEditing = true
                        }
                    }
                }
                
                if isEditing {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            editedForker = forker
                            isEditing = false
                        }
                    }
                }
            }
        }
    }
} 
