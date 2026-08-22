import MusicTheory
import SwiftUI

/// Lays out degree buttons like a keyboard: the mode's seven diatonic degrees
/// plus the high tonic in a bottom row, chromatic degrees in a row above,
/// each centred on the gap between its diatonic neighbours.
///
/// `button` receives a semitone offset 0...12 above the tonic (12 = the high
/// tonic, shown whenever 0 is visible). Hidden offsets leave empty slots so
/// the spatial scale layout stays stable.
struct DegreeRows<Content: View>: View {
    let mode: Mode
    /// Semitones 0...11 to show.
    let visible: Set<Int>
    var buttonSize: CGFloat = 36
    var spacing: CGFloat = 5
    @ViewBuilder let button: (Int) -> Content

    private var diatonicOffsets: [Int] { mode.intervals + [12] }
    private var chromaticOffsets: [Int] { (1...11).filter { !mode.intervals.contains($0) } }
    private var rowWidth: CGFloat { 8 * buttonSize + 7 * spacing }

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topLeading) {
                Color.clear
                    .frame(width: rowWidth, height: buttonSize)
                ForEach(chromaticOffsets.filter { visible.contains($0) }, id: \.self) { offset in
                    button(offset)
                        .frame(width: buttonSize, height: buttonSize)
                        .offset(x: chromaticX(offset))
                }
            }
            HStack(spacing: spacing) {
                ForEach(diatonicOffsets, id: \.self) { offset in
                    Group {
                        if visible.contains(offset % 12) {
                            button(offset)
                        } else {
                            Color.clear
                        }
                    }
                    .frame(width: buttonSize, height: buttonSize)
                }
            }
        }
    }

    /// Leading x of a chromatic button, centred on the gap between the
    /// diatonic slots on either side of it.
    private func chromaticX(_ offset: Int) -> CGFloat {
        let lowerIndex = mode.intervals.filter { $0 < offset }.count - 1
        let gapCenter = CGFloat(lowerIndex + 1) * (buttonSize + spacing) - spacing / 2
        return gapCenter - buttonSize / 2
    }
}
