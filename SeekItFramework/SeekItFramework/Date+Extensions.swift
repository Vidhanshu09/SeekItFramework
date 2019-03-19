//
//  Date+Extensions.swift
//  SeekLib
//
//  Created by Jitendra Chamoli on 09/10/18.
//

import Foundation

class DateUtility {
    
    static var dateFormat = "yyyy-MM-dd HH:mm:ssSSS"
    static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        return formatter
    }
    static var dateFormat2 = "MMM dd, hh:mm a"
    static var dF: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat2
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        return formatter
    }
    static var dateFormat3 = "hh:mm:ss a"
    static var dateFormatter3: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = dateFormat3
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"
        formatter.timeZone = TimeZone.current
        return formatter
    }
}

// 2. The Date to String extension
extension Date {
    func toString() -> String {
        return DateUtility.dateFormatter3.string(from: self as Date)
    }
    func toTime() -> String {
        return DateUtility.dateFormatter.string(from: self as Date)
    }
}

extension Date {
    // Convert local time to UTC (or GMT)
    func toGlobalTime() -> Date {
        let timezone = TimeZone.current
        let seconds = -TimeInterval(timezone.secondsFromGMT(for: self))
        return Date(timeInterval: seconds, since: self)
    }
    // Convert UTC (or GMT) to local time
    func toLocalTime() -> Date {
        let timezone = TimeZone.current
        let seconds = TimeInterval(timezone.secondsFromGMT(for: self))
        return Date(timeInterval: seconds, since: self)
    }
}


// Epoch to String
extension Double {
    func getDateStringFromUnixTime(dateStyle: DateFormatter.Style, timeStyle: DateFormatter.Style) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = dateStyle
        dateFormatter.timeStyle = timeStyle
        return dateFormatter.string(from: Date(timeIntervalSince1970: self))
    }
}

extension Date {
    
    var getElapsedInterval: String {
        //return getTimeAgoSinceNow()
        return getPastTime()
    }
    
    private func getTimeAgoSinceNow() -> String {
        
        var interval = Calendar.current.dateComponents([.year], from: self, to: Date()).year!
        if interval > 0 {
            return interval == 1 ? "\(interval)" + " year ago" : "\(interval)" + " years ago"
        }
        
        interval = Calendar.current.dateComponents([.month], from: self, to: Date()).month!
        if interval > 0 {
            return interval == 1 ? "\(interval)" + " month ago" : "\(interval)" + " months ago"
        }
        
        interval = Calendar.current.dateComponents([.day], from: self, to: Date()).day!
        if interval > 0 {
            return interval == 1 ? "\(interval)" + " day ago" : "\(interval)" + " days ago"
        }
        
        interval = Calendar.current.dateComponents([.hour], from: self, to: Date()).hour!
        if interval > 0 {
            return interval == 1 ? "\(interval)" + " hour ago" : "\(interval)" + " hours ago"
        }
        
        interval = Calendar.current.dateComponents([.minute], from: self, to: Date()).minute!
        if interval > 0 {
            return interval == 1 ? "\(interval)" + " minute ago" : "\(interval)" + " minutes ago"
        }
        
        interval = Calendar.current.dateComponents([.second], from: self, to: Date()).second!
        if interval > 0 {
            return interval == 1 ? "\(interval)" + " second ago" : "\(interval)" + " seconds ago"
        }
        return "Just Now"
    }
    
    func getPastTime() -> String {
        
        var secondsAgo = Int(Date().timeIntervalSince(self))
        if secondsAgo < 0 {
            secondsAgo = secondsAgo * (-1)
        }
        
        let minute = 60
        let hour = 60 * minute
        let day = 24 * hour
        let week = 7 * day
        
        if secondsAgo < minute  {
            if secondsAgo < 2{
                return "just now"
            }else{
                return "\(secondsAgo) secs ago"
            }
        } else if secondsAgo < hour {
            let min = secondsAgo/minute
            if min == 1{
                return "\(min) min ago"
            }else{
                return "\(min) mins ago"
            }
        } else if secondsAgo < day {
            let hr = secondsAgo/hour
            if hr == 1{
                return "\(hr) hr ago"
            } else {
                return "\(hr) hrs ago"
            }
        } else if secondsAgo < week {
            let day = secondsAgo/day
            if day == 1{
                return "\(day) day ago"
            }else{
                return "\(day) days ago"
            }
        } else {
            /*let formatter = DateFormatter()
             formatter.dateFormat = "MMM dd, hh:mm a"
             formatter.locale = Locale(identifier: "en_US")*/
            let strDate: String = DateUtility.dF.string(from: self)
            return strDate
        }
    }
}

// MARK:- ISO8601 Date Formatter
extension Date {
    struct Formatter {
        static let iso8601: DateFormatter = {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .iso8601)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "UTC")
            formatter.dateFormat = "dd/MM/yyyy"
            return formatter
        }()
    }
    var iso8601: String {
        var data = Formatter.iso8601.string(from: self)
        if let fractionStart = data.range(of: "."),
            let fractionEnd = data.index(fractionStart.lowerBound, offsetBy: 7, limitedBy: data.endIndex) {
            let fractionRange = fractionStart.lowerBound..<fractionEnd
            let intVal = Int64(1000000 * self.timeIntervalSince1970)
            let newFraction = String(format: ".%06d", intVal % 1000000)
            data.replaceSubrange(fractionRange, with: newFraction)
        }
        return data
    }
}

extension String {
    var dateFromISO8601: Date? {
        guard let parsedDate = Date.Formatter.iso8601.date(from: self) else {
            return nil
        }
        var preliminaryDate = Date(timeIntervalSinceReferenceDate: floor(parsedDate.timeIntervalSinceReferenceDate))
        if let fractionStart = self.range(of: "."),
            let fractionEnd = self.index(fractionStart.lowerBound, offsetBy: 7, limitedBy: self.endIndex) {
            let fractionRange = fractionStart.lowerBound..<fractionEnd
            let fractionStr = self.substring(with: fractionRange)
            
            if var fraction = Double(fractionStr) {
                fraction = Double(floor(1000000*fraction)/1000000)
                preliminaryDate.addTimeInterval(fraction)
            }
        }
        return preliminaryDate
    }
}

extension Date {
    
    func ToLocalStringWithFormat(dateFormat: String) -> String? {
        // change to a readable time format and change to local time zone
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = dateFormat
        dateFormatter.timeZone = NSTimeZone.local
        let timeStamp = dateFormatter.string(from: self)
        
        return timeStamp
    }
}

// Date and Time

protocol Dateable {
    func userFriendlyFullDate() -> String
    func userFriendlyHours() -> String
}

extension Date: Dateable {
    var  formatter: DateFormatter { return DateFormatter() }
    
    /** Return a user friendly hour */
    func userFriendlyFullDate() -> String {
        // Customize a date formatter
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        
        return formatter.string(from: self)
    }
    
    /** Return a user friendly hour */
    func userFriendlyHours() -> String {
        // Customize a date formatter
        let calendar = Calendar.current
        
        let hour = calendar.component(.hour, from: self) //11
        let minute = calendar.component(.minute, from: self) //55
        //        //let sec = calendar.component(.second, from: date) //33
        //        //let weekDay = calendar.component(.weekday, from: date) //6 (Friday)
        //
        //
        //formatter.dateFormat = "HH:mm"
        
        //formatter.timeZone = TimeZone(abbreviation: "UTC")
        //print(formatter.string(from: self))
        //return  "\(String(format: "%02d", hour)):\(String(format: "%02d", minute))"
        return String(format: "%02d:%02d", hour, minute)
        //return formatter.string(from: self)
    }
    
    // You can add many cases you need like string to date formatter
}

extension Date {
    var yesterday: Date {
        return Calendar.current.date(byAdding: .day, value: -1, to: noon)!
    }
    var tomorrow: Date {
        return Calendar.current.date(byAdding: .day, value: 1, to: noon)!
    }
    var noon: Date {
        return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: self)!
    }
    var month: Int {
        return Calendar.current.component(.month,  from: self)
    }
    var isLastDayOfMonth: Bool {
        return tomorrow.month != month
    }
}

extension Date {
    
    func years(sinceDate: Date) -> Int? {
        return Calendar.current.dateComponents([.year], from: sinceDate, to: self).year
    }
    
    func months(sinceDate: Date) -> Int? {
        return Calendar.current.dateComponents([.month], from: sinceDate, to: self).month
    }
    
    func days(sinceDate: Date) -> Int? {
        return Calendar.current.dateComponents([.day], from: sinceDate, to: self).day
    }
    
    func hours(sinceDate: Date) -> Int? {
        return Calendar.current.dateComponents([.hour], from: sinceDate, to: self).hour
    }
    
    func minutes(sinceDate: Date) -> Int? {
        return Calendar.current.dateComponents([.minute], from: sinceDate, to: self).minute
    }
    
    func seconds(sinceDate: Date) -> Int? {
        return Calendar.current.dateComponents([.second], from: sinceDate, to: self).second
    }
    
}

struct DateComponentUnitFormatter {
    
    private struct DateComponentUnitFormat {
        let unit: Calendar.Component
        
        let singularUnit: String
        let pluralUnit: String
        
        let futureSingular: String
        let pastSingular: String
    }
    
    private let formats: [DateComponentUnitFormat] = [
        
        DateComponentUnitFormat(unit: .year,
                                singularUnit: "year",
                                pluralUnit: "years",
                                futureSingular: "Next year",
                                pastSingular: "Last year"),
        
        DateComponentUnitFormat(unit: .month,
                                singularUnit: "month",
                                pluralUnit: "months",
                                futureSingular: "Next month",
                                pastSingular: "Last month"),
        
        DateComponentUnitFormat(unit: .weekOfYear,
                                singularUnit: "week",
                                pluralUnit: "weeks",
                                futureSingular: "Next week",
                                pastSingular: "Last week"),
        
        DateComponentUnitFormat(unit: .day,
                                singularUnit: "day",
                                pluralUnit: "days",
                                futureSingular: "Tomorrow",
                                pastSingular: "Yesterday"),
        
        DateComponentUnitFormat(unit: .hour,
                                singularUnit: "hour",
                                pluralUnit: "hours",
                                futureSingular: "In an hour",
                                pastSingular: "An hour ago"),
        
        DateComponentUnitFormat(unit: .minute,
                                singularUnit: "minute",
                                pluralUnit: "minutes",
                                futureSingular: "In a minute",
                                pastSingular: "A minute ago"),
        
        DateComponentUnitFormat(unit: .second,
                                singularUnit: "second",
                                pluralUnit: "seconds",
                                futureSingular: "Just now",
                                pastSingular: "Just now"),
        
        ]
    
    func string(forDateComponents dateComponents: DateComponents, useNumericDates: Bool) -> String {
        for format in self.formats {
            let unitValue: Int
            
            switch format.unit {
            case .year:
                unitValue = dateComponents.year ?? 0
            case .month:
                unitValue = dateComponents.month ?? 0
            case .weekOfYear:
                unitValue = dateComponents.weekOfYear ?? 0
            case .day:
                unitValue = dateComponents.day ?? 0
            case .hour:
                unitValue = dateComponents.hour ?? 0
            case .minute:
                unitValue = dateComponents.minute ?? 0
            case .second:
                unitValue = dateComponents.second ?? 0
            default:
                assertionFailure("Date does not have requried components")
                return ""
            }
            
            switch unitValue {
            case 2 ..< Int.max:
                return "\(unitValue) \(format.pluralUnit) ago"
            case 1:
                return useNumericDates ? "\(unitValue) \(format.singularUnit) ago" : format.pastSingular
            case -1:
                return useNumericDates ? "In \(-unitValue) \(format.singularUnit)" : format.futureSingular
            case Int.min ..< -1:
                return "In \(-unitValue) \(format.pluralUnit)"
            default:
                break
            }
        }
        
        return "Just now"
    }
}

extension Date {
    
    public func timeAgoSinceNow(useNumericDates: Bool = false) -> String {
        
        let calendar = Calendar.current
        let unitFlags: Set<Calendar.Component> = [.minute, .hour, .day, .weekOfYear, .month, .year, .second]
        let now = Date()
        let components = calendar.dateComponents(unitFlags, from: self, to: now)
        
        let formatter = DateComponentUnitFormatter()
        return  "Seen " + formatter.string(forDateComponents: components, useNumericDates: useNumericDates)
    }
}
