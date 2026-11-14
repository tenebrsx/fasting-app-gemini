import Foundation

enum Formatters {
    private static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.timeStyle = .short
        df.dateStyle = .none
        return df
    }()

    private static let weekdayTimeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.setLocalizedDateFormatFromTemplate("EEE jmm")
        return df
    }()

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.setLocalizedDateFormatFromTemplate("EEE MMM d")
        return df
    }()

    private static let fullFormatter: DateFormatter = {
        let df = DateFormatter()
        df.setLocalizedDateFormatFromTemplate("EEE MMM d jmm")
        return df
    }()

    static func hms(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    static func duration(_ interval: TimeInterval) -> String {
        let totalMinutes = max(0, Int((interval / 60.0).rounded()))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        }
        return "\(minutes)m"
    }

    static func hoursLabel(_ hours: Double) -> String {
        if hours.rounded() == hours {
            return "\(Int(hours))h"
        }
        return String(format: "%.1fh", hours)
    }

    static func timeOnly(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    static func fullDateTime(_ date: Date) -> String {
        fullFormatter.string(from: date)
    }

    static func smartTime(_ date: Date, relativeTo now: Date = Date()) -> String {
        let cal = Calendar.current
        if cal.isDate(date, inSameDayAs: now) {
            return "Today \(timeFormatter.string(from: date))"
        }
        if let yesterday = cal.date(byAdding: .day, value: -1, to: now),
           cal.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday \(timeFormatter.string(from: date))"
        }
        if let tomorrow = cal.date(byAdding: .day, value: 1, to: now),
           cal.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow \(timeFormatter.string(from: date))"
        }
        if abs(now.timeIntervalSince(date)) < 6 * 86400 {
            return weekdayTimeFormatter.string(from: date)
        }
        return fullFormatter.string(from: date)
    }

    static func dayTitle(_ day: Date, relativeTo now: Date = Date()) -> String {
        let cal = Calendar.current
        if cal.isDate(day, inSameDayAs: now) {
            return "Today"
        }
        if let yesterday = cal.date(byAdding: .day, value: -1, to: now),
           cal.isDate(day, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        return dateFormatter.string(from: day)
    }
}
