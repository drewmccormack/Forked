import SwiftUI

struct ForkerRow: View {
    let forker: Forker
    
    private var displayName: String {
        [forker.firstName, forker.lastName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
    
    var body: some View {
        HStack {
            Image(systemName: forker.category?.systemImage ?? "person.circle.fill")
                .foregroundStyle(forker.color?.color ?? .accentColor)
                .font(.title2)
                .frame(width: 30)
                .symbolRenderingMode(.monochrome)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.headline)
                if !forker.company.isEmpty {
                    Text(forker.company)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(height: 44)
    }
} 