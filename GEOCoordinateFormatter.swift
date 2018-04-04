//
//  GEOCoordinateFormatter.swift
//  GEOCoordinateFormatter
//
//  Created by Martin Kiss on 3 Apr 2018.
//  https://github.com/Tricertops/GEOCoordinateFormatter
//
//  The MIT License (MIT)
//  Copyright © Martin Kiss
//

import Foundation
import CoreLocation


/// An NSFormatter that creates human-readable strings of geographic coordinates.
/// Default format for new instance is: 12° 34′ N, 12° 34′ W
@objc public class GEOCoordinateFormatter: Formatter {
    
    //MARK:  Precision & Locale
    /// Locale used to format numbers, passed to the underlaying NSNumberFormatter.
    @objc public var locale: Locale = Locale(identifier: "en_US_POSIX")
    /// Specify which units will be used. This formatter always prints all larger units, for example 0° 0′ 3″ (smallestUnit = seconds).
    @objc public var smallestUnit: GEOCoordinateFormatterUnit = .minutes
    /// Specify how many digits beyond integer degrees should be printed, degrees are always printer with up to 3 integer digits. After using all integer digits allowed by smallestUnit, the smallest unit will get fractional digits. For example 12° 34.567′ (smallestUnit = minutes,  precisionDigits = 5).
    @objc public var precisionDigits: UInt = 2
    
    /// To get a sense of distances, here is a convenient table for equator.
    /// Keep in mind that longitudal resolution decreases toward poles.
    ///   1°  = 111 km  (smallestUnit = degrees,  precisionDigits = 0)
    ///   0.1°  = 11.1 km  (smallestUnit = degrees,  precisionDigits = 1)
    ///   0° 1′  = 1.86 km  (smallestUnit = minutes,  precisionDigits = 1)
    ///   0° 0.1′  = 186 m  (smallestUnit = minutes,  precisionDigits = 2)
    ///   0° 0′ 1″  = 31 m  (smallestUnit = seconds,  precisionDigits = 2)
    ///   0° 0′ 0.1″  = 3.1 m  (smallestUnit = seconds,  precisionDigits = 3)
    ///   0° 0′ 0.01″  = 31 cm  (smallestUnit = seconds,  precisionDigits = 4)
    ///   0° 0′ 0.001″  = 3.1 cm  (smallestUnit = seconds,  precisionDigits = 5)
    
    //MARK:  Units & Separators
    /// Customize string to be used as degrees unit string. This string will be adjacent to the number, so include leading space as needed.
    @objc public var degreeString: String = "°" // U+00B0 DEGREE SIGN
    /// Customize string to be used as minues unit string. This string will be adjacent to the number, so include leading space as needed.
    @objc public var minuteString: String = "′" // U+2032 PRIME
    /// Customize string to be used as seconds unit string. This string will be adjacent to the number, so include leading space as needed.
    @objc public var secondString: String = "″" // U+2033 DOUBLE PRIME
    /// Customize string that will be inserted between degrees, minutes, and seconds.
    @objc public var componentSeparator: String = " " // U+0020 SPACE
    
    //MARK:  Hemispheres
    /// Specify whether the formatter appends hemisphere suffix after the coordinate. If false, the formatter will use minusSign to indicate Southern or Western hemisphere. Examples 12° 34′ W and −12° 34′.
    @objc public var usesHemisphereSuffixes: Bool = true
    /// Customize minus sign when printing without hemisphere suffixes. You may prefer hyphen (U+002D HYPHEN-MINUS).
    @objc public var minusSign: String = "−" // U+2212 MINUS SIGN
    /// Customize string to be used for North hemisphere. This is not localized automatically.
    @objc public var northString: String = "N"
    /// Customize string to be used for South hemisphere. This is not localized automatically.
    @objc public var southString: String = "S"
    /// Customize string to be used for East hemisphere. This is not localized automatically.
    @objc public var eastString: String = "E"
    /// Customize string to be used for West hemisphere. This is not localized automatically.
    @objc public var westString: String = "W"
    
    //MARK:  Formatting
    /// Builds coordinate format for no specific axis. Appends no hemishpere suffix, but respects the configuration.
    @objc public func stringFor(number: Double) -> String {
        return self.buildFormat(number: number, axis: .undefined)
    }
    /// Builds coordinate format for latitude. Appends North/South suffix, if configured so.
    @objc public func stringFor(latitude: Double) -> String {
        return self.buildFormat(number: latitude, axis: .latitudal)
    }
    /// Builds coordinate format for longitude. Appends East/West suffix, if configured so.
    @objc public func stringFor(longitude: Double) -> String {
        return self.buildFormat(number: longitude, axis: .longitudal)
    }
    /// Builds coordinate format for both latitude and longitude. Joins them using comma.
    @objc public func stringFor(coordinate: CLLocationCoordinate2D) -> String {
        return self.stringFor(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
    /// Builds coordinate format for both latitude and longitude. Joins them using comma.
    @objc public func stringFor(latitude: Double, longitude: Double) -> String {
        let latitudeString = self.buildFormat(number: latitude, axis: .latitudal)
        let longitudeString = self.buildFormat(number: longitude, axis: .longitudal)
        return latitudeString + ", " + longitudeString
    }
}

/// List of all possible units, that can be used with GEOCoordinateFormatter.
@objc public enum GEOCoordinateFormatterUnit: Int {
    case degrees = 0
    case minutes = 1
    case seconds = 2
}





//MARK: - Implementation Details


extension GEOCoordinateFormatter {
    
    @objc public override func string(for object: Any?) -> String? {
        switch object {
            
        // Simple numbers are formatted with undefined axis. Pass NSNumber from Objective-C.
        case let number as Double:
            return self.stringFor(number: number)
            
        // Compound coordinates are formatted properly. Pass NSValue from Objective-C.
        case let coordinate as CLLocationCoordinate2D:
            return self.stringFor(coordinate: coordinate)
            
        // Accepts arrays of number with length of 2.
        case let array as [Double] where array.count == 2:
            return self.stringFor(latitude: array[0], longitude: array[1])
            
        default:
            return nil
        }
    }
    
    private enum Axis {
        case undefined
        case latitudal
        case longitudal
    }
    
    private func buildFormat(number: Double, axis: Axis) -> String {
        if number.isNaN || number.isInfinite {
            return ""
        }
        let decomposed = self.decompose(number: number)
        
        var components: [String]
        let formatter = self.makeNumberFormatter()
        // Number of digits beyond integer degrees.
        var precision = Int(self.precisionDigits)
        
        switch self.smallestUnit {
        case .degrees:
            //  12.34567° S
            // -12.34567°
            
            let degrees = self.format(number: number, precision: precision, formatter: formatter)
            components = [degrees]
            
        case .minutes:
            //  12° 34.567′ S
            // -12° 34.567′
            
            // Two digits are consumed by integer minutes.
            precision -= 2
            
            let degreesString = self.format(number: decomposed.degrees, precision: 0, formatter: formatter)
            let minutesString = self.format(number: decomposed.minutes, precision: precision, formatter: formatter)
            components = [degreesString, minutesString]
            
        case .seconds:
            //  12° 34′ 56.7″ S
            // -12° 34′ 56.7″
            
            // Two digits are consumed by integer minutes.
            // Two digits are consumed by integer seconds.
            precision -= 4
            
            let degreesString = self.format(number: decomposed.degrees, precision: 0, formatter: formatter)
            let minutesString = self.format(number: decomposed.minutes, precision: 0, formatter: formatter)
            let secondsString = self.format(number: decomposed.seconds, precision: precision, formatter: formatter)
            components = [degreesString, minutesString, secondsString]
        }
        
        if self.usesHemisphereSuffixes {
            let hemisphere = self.hemisphereSufffix(for: axis, negative: (number < 0))
            if !hemisphere.isEmpty {
                components.append(hemisphere)
            }
        }
        
        return components.joined(separator: self.componentSeparator)
    }
    
    private func makeNumberFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = self.locale
        formatter.numberStyle = .decimal
        formatter.minusSign = self.minusSign
        formatter.usesGroupingSeparator = false
        formatter.minimumIntegerDigits = 1
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter
    }
    
    private func decompose(number: Double) -> (degrees: Double, minutes: Double, seconds: Double) {
        // Number of digits beyond integer degrees.
        var precision = Int(self.precisionDigits)
        
        switch self.smallestUnit {
        case .degrees:
            // The number is degrees.
            return (number, 0, 0)
            
        case .minutes:
            precision -= 2
            
            // Degrees are simply rounded.
            var degrees = abs(number)
            // Minutes are 60× the fractional part.
            var minutes = degrees.remainder(dividingBy: 1) * 60
            
            degrees.round(.towardZero)
            minutes = self.rounded(number: minutes, fractionalDigits: precision)
            
            // If rounding overflowed valid range, increment higher unit.
            if minutes > 60 {
                minutes -= 60
                degrees += 1
            }
            // If we need to use minus sign, negate degrees.
            if !self.usesHemisphereSuffixes && number < 0 {
                degrees *= -1
            }
            
            return (degrees, minutes, 0)
            
        case .seconds:
            // Two digits are consumed by integer minutes.
            // Two digits are consumed by integer seconds.
            precision -= 4
            
            // Degrees are simply rounded.
            var degrees = abs(number)
            // Minutes and seconds are 60× the fractional part.
            var minutes = degrees.remainder(dividingBy: 1) * 60
            var seconds = minutes.remainder(dividingBy: 1) * 60
            
            degrees.round(.towardZero)
            minutes.round(.towardZero)
            seconds = self.rounded(number: seconds, fractionalDigits: precision)
            
            // If rounding overflowed valid range, increment higher unit.
            if seconds > 60 {
                seconds -= 60
                minutes += 1
            }
            if minutes > 60 {
                minutes -= 60
                degrees += 1
            }
            // If we need to use minus sign, negate degrees.
            if !self.usesHemisphereSuffixes && number < 0 {
                degrees *= -1
            }
            
            return (degrees, minutes, seconds)
        }
    }
    
    private func rounded(number: Double, fractionalDigits: Int) -> Double {
        let roundingScale = pow(10.0, Double(fractionalDigits))
        return (number * roundingScale).rounded() / roundingScale
    }
    
    private func format(number: Double, precision: Int, formatter: NumberFormatter) -> String {
        let precision = max(precision, 0)
        formatter.minimumFractionDigits = precision
        formatter.maximumFractionDigits = precision
        return formatter.string(from: number as NSNumber)!
    }
    
    private func hemisphereSufffix(for axis: Axis, negative: Bool) -> String {
        switch axis {
        case .undefined: return ""
        case .latitudal: return (negative ? self.southString : self.northString)
        case .longitudal: return (negative ? self.westString : self.eastString)
        }
    }
}




