import SwiftUI

struct ForkerRow: View {
    let forker: Forker
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("\(forker.firstName) \(forker.lastName)")
                .font(.headline)
            if !forker.company.isEmpty {
                Text(forker.company)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
} 