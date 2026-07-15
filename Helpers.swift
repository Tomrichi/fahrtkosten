import Foundation
import SwiftUI
import UIKit

// MARK: - Formatters
extension Double {
    var euroFormatted: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.decimalSeparator = ","
        f.groupingSeparator = "."
        return (f.string(from: NSNumber(value: self)) ?? "0,00") + " €"
    }

    var chfFormatted: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.decimalSeparator = ","
        f.groupingSeparator = "."
        return (f.string(from: NSNumber(value: self)) ?? "0,00") + " CHF"
    }

    var kmFormatted: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 0
        f.decimalSeparator = ","
        return (f.string(from: NSNumber(value: self)) ?? "0,0") + " km"
    }
}

extension Date {
    var shortDate: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: self)
    }

    var shortDateShort: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "dd. MMM"
        return f.string(from: self)
    }

    var weekdayShortDate: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "EEE, dd. MMM"
        return f.string(from: self)
    }

    var timeOnly: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: self)
    }
}

// MARK: - Color helpers
extension Color {
    static let iosGreen  = Color(red: 52/255,  green: 199/255, blue: 89/255)
    static let iosOrange = Color(red: 255/255, green: 149/255, blue: 0/255)
    static let iosRed    = Color(red: 255/255, green: 59/255,  blue: 48/255)
    static let iosPurple = Color(red: 175/255, green: 82/255,  blue: 222/255)
    static let iosIndigo = Color(red: 88/255,  green: 86/255,  blue: 214/255)
    static let iosTeal   = Color(red: 90/255,  green: 200/255, blue: 250/255)
}

// MARK: - Accessibility: Reduce Motion
@discardableResult
func withOptionalAnimation<R>(_ animation: Animation? = .default, _ body: () throws -> R) rethrows -> R {
    if UIAccessibility.isReduceMotionEnabled {
        return try body()
    } else {
        return try withAnimation(animation, body)
    }
}

// MARK: - Currency input helper
func parseCurrency(_ s: String) -> Double {
    let clean = s.replacingOccurrences(of: ",", with: ".").filter { $0.isNumber || $0 == "." }
    return Double(clean) ?? 0
}
