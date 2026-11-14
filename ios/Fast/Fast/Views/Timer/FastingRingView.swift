import SwiftUI

struct FastingRingView: View {
    let isFasting: Bool
    let elapsed: TimeInterval
    let sinceLastFast: TimeInterval?
    let targetHours: Double

    private let ringSize: CGFloat = 280
    private let lineWidth: CGFloat = 18

    private var elapsedHours: Double {
        elapsed / 3600.0
    }

    private var progress: Double {
        guard isFasting, targetHours > 0 else { return 0 }
        return min(max(elapsedHours / targetHours, 0), 1.0)
    }

    var body: some View {
        ZStack {
            // Base track
            Circle()
                .stroke(Theme.line, lineWidth: lineWidth)
                .frame(width: ringSize, height: ringSize)

            // Multi-segment zone arcs
            if isFasting {
                ForEach(Array(FastingZone.all.enumerated()), id: \.element.id) { index, zone in
                    let nextHours = index + 1 < FastingZone.all.count
                        ? FastingZone.all[index + 1].hours
                        : Double.infinity
                    if zone.hours < targetHours {
                        let startFrac = zone.hours / targetHours
                        let endFrac = min(nextHours, targetHours, max(elapsedHours, 0)) / targetHours
                        if endFrac > startFrac {
                            Circle()
                                .trim(from: startFrac, to: min(endFrac, 0.9999))
                                .stroke(
                                    zone.color.opacity(zone.opacity),
                                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
                                )
                                .rotationEffect(.degrees(-90))
                                .frame(width: ringSize, height: ringSize)
                        }
                    }
                }

                // Zone tick dots and hour labels
                let radius = ringSize / 2
                ForEach(FastingZone.all.filter { $0.hours > 0 && $0.hours < targetHours }) { zone in
                    let frac = zone.hours / targetHours
                    let angle = Angle.radians(frac * 2 * .pi - .pi / 2)
                    let tickX = cos(angle.radians) * radius
                    let tickY = sin(angle.radians) * radius
                    let labelRadius = radius - 26
                    let labelX = cos(angle.radians) * labelRadius
                    let labelY = sin(angle.radians) * labelRadius

                    Circle()
                        .fill(Theme.bg)
                        .frame(width: 7, height: 7)
                        .offset(x: tickX, y: tickY)

                    Text(Formatters.hoursLabel(zone.hours))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.mist)
                        .offset(x: labelX, y: labelY)
                }

                // Progress head indicator
                let headFrac = progress >= 1.0 ? 0.9999 : progress
                let headAngle = Angle.radians(headFrac * 2 * .pi - .pi / 2)
                let radiusHead = ringSize / 2
                Circle()
                    .fill(Theme.ink)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(Theme.bg, lineWidth: 3))
                    .shadow(color: .black.opacity(0.3), radius: 4)
                    .offset(
                        x: cos(headAngle.radians) * radiusHead,
                        y: sin(headAngle.radians) * radiusHead
                    )
            }

            // Center text
            VStack(spacing: 6) {
                Text(captionText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.mist)
                    .textCase(.uppercase)
                    .tracking(0.8)

                Text(centerTimeText)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)

                subText
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.mist)
            }
            .padding(.horizontal, 36)
            .multilineTextAlignment(.center)
        }
        .frame(width: ringSize + 24, height: ringSize + 24)
        .accessibilityElement(children: .combine)
    }

    private var captionText: String {
        if isFasting {
            return elapsedHours >= targetHours ? "Goal reached" : "Elapsed"
        }
        return sinceLastFast != nil ? "Since your last fast" : "Ready when you are"
    }

    private var centerTimeText: String {
        if isFasting {
            return Formatters.hms(elapsed)
        }
        if let sinceLastFast {
            return Formatters.hms(sinceLastFast)
        }
        return "00:00:00"
    }

    @ViewBuilder
    private var subText: some View {
        let targetText = Formatters.hoursLabel(targetHours)
        if isFasting {
            let targetSeconds = targetHours * 3600.0
            if elapsedHours >= targetHours {
                let over = Formatters.hms(elapsed - targetSeconds)
                Text("**+\(over)** past \(targetText)")
            } else {
                let pct = Int(progress * 100)
                let left = Formatters.hms(targetSeconds - elapsed)
                Text("**\(pct)%** of \(targetText) · \(left) left")
            }
        } else {
            Text("Next fast: **\(targetText)**")
        }
    }
}
