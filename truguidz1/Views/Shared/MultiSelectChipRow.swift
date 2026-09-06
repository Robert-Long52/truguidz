import SwiftUI

// Small "chip" multi-select row -- used for picking which weekdays/time
// slots a guide offers. A horizontal scroll rather than a wrapping grid
// since both option lists it's used for here are short (<= 7 items).
struct MultiSelectChipRow<T: Hashable>: View {
    let options: [T]
    @Binding var selection: Set<T>
    let label: (T) -> String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let isSelected = selection.contains(option)
                    Button {
                        if isSelected {
                            selection.remove(option)
                        } else {
                            selection.insert(option)
                        }
                    } label: {
                        Text(label(option))
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isSelected ? Color.accentColor : Color(.systemGray5))
                            .foregroundColor(isSelected ? .white : .primary)
                            .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
