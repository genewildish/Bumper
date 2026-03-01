import SwiftUI

struct AddDebtSheetView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var incrementAmount: Double
    @State private var payoutThreshold: Double

    let onSave: (_ name: String, _ incrementAmount: Double, _ threshold: Double) -> Void

    init(defaultThreshold: Double, onSave: @escaping (_ name: String, _ incrementAmount: Double, _ threshold: Double) -> Void) {
        _incrementAmount = State(initialValue: 1.00)
        _payoutThreshold = State(initialValue: max(defaultThreshold, 5))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Debt details") {
                    TextField("Debt name (e.g. Pinball machine games)", text: $name)
                    Stepper(value: $incrementAmount, in: 0.25 ... 5.0, step: 0.25) {
                        HStack {
                            Text("Increment")
                            Spacer()
                            Text("Bump \(incrementAmount.asCurrency())")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Stepper(value: $payoutThreshold, in: 5 ... 250, step: 5) {
                        HStack {
                            Text("Auto-pay threshold")
                            Spacer()
                            Text(payoutThreshold.asCurrency())
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Text("Bumper is designed for friendly micro-debts under $5 per bump.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New micro-debt")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onSave(name, incrementAmount, payoutThreshold)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
