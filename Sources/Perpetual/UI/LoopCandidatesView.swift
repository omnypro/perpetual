import SwiftUI

struct LoopCandidatesView: View {
    @ObservedObject var analyzer: MusicStructureAnalyzer
    @ObservedObject var audioManager: AudioManager
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Loop Candidates")
                .font(.headline)
            
            if analyzer.loopCandidates.isEmpty {
                Text("No high-quality loop candidates found")
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .padding()
            } else {
                // Loop candidates list
                List {
                    ForEach(analyzer.loopCandidates) { candidate in
                        CandidateRow(
                            candidate: candidate,
                            isSelected: candidate.startTime == analyzer.suggestedLoopStart &&
                                      candidate.endTime == analyzer.suggestedLoopEnd
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Apply this candidate when tapped
                            audioManager.setLoopPoints(start: candidate.startTime, end: candidate.endTime)
                            EventBus.shared.publishLoopPointsChanged()
                        }
                    }
                }
                .frame(height: 200)
                .listStyle(PlainListStyle())
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

struct CandidateRow: View {
    let candidate: MusicStructureAnalyzer.LoopCandidate
    let isSelected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Quality: \(String(format: "%.1f", candidate.quality))/10")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(qualityColor(candidate.quality))
                    
                    Spacer()
                    
                    Text("Start: \(TimeFormatter.formatStandard(candidate.startTime)) → End: \(TimeFormatter.formatStandard(candidate.endTime))")
                        .font(.caption)
                }
                
                HStack(spacing: 12) {
                    MetricView(name: "Vol", value: candidate.metrics.volumeChange, format: "%.1f%%",
                               isGood: candidate.metrics.volumeChange < 10)
                    
                    MetricView(name: "Phase", value: candidate.metrics.phaseJump, format: "%.3f",
                               isGood: candidate.metrics.phaseJump < 0.1)
                    
                    MetricView(name: "Spec", value: candidate.metrics.spectralDifference * 100, format: "%.1f%%",
                               isGood: candidate.metrics.spectralDifference < 0.2)
                    
                    MetricView(name: "Harm", value: candidate.metrics.harmonicContinuity * 100, format: "%.1f%%",
                               isGood: candidate.metrics.harmonicContinuity > 0.7)
                }
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(4)
    }
    
    private func qualityColor(_ quality: Float) -> Color {
        switch quality {
        case 0..<3:
            return .red
        case 3..<5:
            return .orange
        case 5..<7:
            return .yellow
        case 7..<9:
            return .green
        default:
            return .blue
        }
    }
}

struct MetricView: View {
    let name: String
    let value: Float
    let format: String
    let isGood: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.system(size: 8))
                .foregroundColor(.secondary)
            
            Text(String(format: format, value))
                .font(.system(size: 10))
                .foregroundColor(isGood ? .green : .red)
        }
    }
}
