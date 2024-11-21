import SwiftUI

struct CounterView: View {
    @Binding var count: Int

    var body: some View {
        HStack {
            Button(action: {
                count -= 1
            }) {
                Image(systemName: "chevron.down")
                    .frame(width: 20, height: 20)
            }

            TextField("", value: $count, formatter: NumberFormatter())
                .keyboardType(.numberPad)
                .frame(width: 30)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Button(action: {
                count += 1
            }) {
                Image(systemName: "chevron.up")
                    .frame(width: 20, height: 20)
            }
        }
        .padding()
    }
}
