import MusicTheory
import SollaEngine
import SwiftUI

struct SummaryView: View {
    let summary: BenbassatSummary
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("\(summary.correct) / \(summary.total)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("correct")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 32)

            List {
                Section("By degree") {
                    ForEach(ScaleDegree.allCases, id: \.self) { degree in
                        if let stat = summary.perDegree[degree] {
                            HStack {
                                Text(degree.solfege)
                                    .font(.body.weight(.medium))
                                Spacer()
                                Text("\(stat.correct)/\(stat.total)")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)

            Button {
                onDone()
            } label: {
                Text("Done")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .navigationBarBackButtonHidden()
    }
}
