import Foundation

/// Helper struct to provide standardized date formatters throughout the app
struct DateFormatters {
    /// Formatter for displaying time in 24-hour format (HH:mm)
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    /// Formatter for date in ISO format (yyyy-MM-dd)
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    /// Helper function to format travel time between two dates
    static func formatTravelTime(from departureTime: Date, to arrivalTime: Date) -> String {
        let travelTimeInMinutes = Int(arrivalTime.timeIntervalSince(departureTime) / 60)
        
        if travelTimeInMinutes >= 60 {
            let hours = travelTimeInMinutes / 60
            let minutes = travelTimeInMinutes % 60
            if minutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(minutes)m"
            }
        } else {
            return "\(travelTimeInMinutes)m"
        }
    }
    
    static func parseDateFormats(_ dateString: String) -> Date? {
        // Israel Standard Time timezone
        let israelTimeZone = TimeZone(identifier: "Asia/Jerusalem") ?? TimeZone.current
        
        // Try with ISO8601 formatter first
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateString) {
            return date
        }
        
        // Create a reusable date formatter
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = israelTimeZone
        
        // Array of potential date formats
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd HH:mm:ss"
        ]
        
        // Try each format
        for format in formats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
    
    static func formatDateLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return ":"
        } else {
            let dayMonthYearFormatter = DateFormatter()
            dayMonthYearFormatter.dateFormat = "EEEE, d MMM"
            return " (\(dayMonthYearFormatter.string(from: date))):"
        }
    }
}
