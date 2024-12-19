import SwiftUI

struct EditForkerView: View {
    @Binding var forker: Forker
    
    var body: some View {
        Form {
            Section("Basic Info") {
                TextField("First Name", text: $forker.firstName)
                TextField("Last Name", text: $forker.lastName)
                TextField("Company", text: $forker.company)
                TextField("Email", text: $forker.email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
            }
            
            Section("Additional Info") {
                DatePicker(
                    "Birthday",
                    selection: Binding(
                        get: { forker.birthday ?? Date() },
                        set: { forker.birthday = $0 }
                    ),
                    displayedComponents: .date
                )
                
                LabeledContent("Owes Me") {
                    TextField("Amount", value: $forker.balance.dollarAmount, format: .number.precision(.fractionLength(2)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                
                Picker("Category", selection: $forker.category) {
                    Text("None")
                        .tag(Optional<ForkerCategory>.none)
                    ForEach(ForkerCategory.allCases, id: \.self) { category in
                        Label(category.rawValue.capitalized, systemImage: category.systemImage)
                            .tag(Optional(category))
                    }
                }
                .pickerStyle(.navigationLink)
                
                Picker("Color", selection: $forker.color) {
                    Text("None")
                        .tag(Optional<ForkerColor>.none)
                    ForEach(ForkerColor.allCases, id: \.self) { color in
                        Label(color.rawValue.capitalized, systemImage: "circle.fill")
                            .foregroundStyle(color.color)
                            .tag(Optional(color))
                    }
                }
                .pickerStyle(.navigationLink)
                
                TextField("Tags", text: Binding(
                    get: {
                        forker.tags.joined(separator: " ")
                    },
                    set: { newValue in
                        let tags = newValue.components(separatedBy: CharacterSet(charactersIn: "-_").union(.punctuationCharacters).symmetricDifference(.punctuationCharacters).union(.whitespaces))
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                        forker.tags = Set(tags)
                    }
                ))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                
                TextField("Notes", text: $forker.notes, axis: .vertical)
                    .lineLimit(5...10)
            }
        }
    }
}
