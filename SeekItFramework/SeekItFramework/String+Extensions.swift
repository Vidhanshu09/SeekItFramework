//
//  String+Extensions.swift
//  SeekLib
//
//  Created by Jitendra Chamoli on 09/10/18.
//

import Foundation

let alphabet = "^[a-zA-Z]"
let numeric  = "^[0-9]"

extension String {
    
    // Function to validation Any Email ID
    
    func isValidEmail() -> Bool {
        
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,4}"
        let emailTest = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        let result = emailTest.evaluate(with: self)
        return result
    }
    
    func isValidUserName() ->Bool {
        let userNameRegEx = "^[a-zA-Z0-9_ ]{3,20}"
        let unTest = NSPredicate(format:"SELF MATCHES %@", userNameRegEx)
        let result = unTest.evaluate(with: self)
        return result
    }
    
    func isValidName() ->Bool{
        let alphabetRegEx = "^[a-zA-Z]{3,20}"//$
        let nameTest = NSPredicate(format:"SELF MATCHES %@", alphabetRegEx)
        let result = nameTest.evaluate(with: self)
        return result
    }
    
    fileprivate func isValidPassword() ->Bool{
        //        let alphabetRegEx = "^(?=.*[A-Z])(/password/ig)(?=.*[`~!@#$%^&*()-_=+[]{}\\|;:\'\"<,>./?])(?=.*[0-9])(?=.*[a-z])(?!.*?password).{10,50}$"//$
        let alphabetRegEx = "^(?=.*[A-Z])(?=.*[`~!@#$%^&*()-_=+/[/]{}\\|;:\'\"<,>./?])(?=.*[0-9])(?=.*[a-z])(?!.*?password).{10,50}$"//$
        
        let nameTest = NSPredicate(format:"SELF MATCHES %@", alphabetRegEx)
        let result = nameTest.evaluate(with: self)
        if result{
            return self.containsOnlyLetters(input: self)
        }
        return result
    }
    
    fileprivate func containsOnlyLetters(input: String) -> Bool {
        let isDotAvailable: Bool = input.contains(".")
        return !isDotAvailable
    }
    
    fileprivate func isNumber() -> Bool {
        let numberCharacters = NSCharacterSet.alphanumerics.inverted
        return !self.isEmpty && self.rangeOfCharacter(from: numberCharacters) == nil
    }
    
    fileprivate func isValidDOB () -> Bool {
        let dobRegEx = "^(0[1-9]|1[012])[-/.](0[1-9]|[12][0-9]|3[01])[-/.](19|20)\\d\\d$"
        let dobTest = NSPredicate(format:"SELF MATCHES %@", dobRegEx)
        let result = dobTest.evaluate(with: self)
        return result
    }
    
    func isValidPhoneNumber() ->Bool {
        //REGEX_FOR_NUMBERS   @"^([+-]?)(?:|0|[1-9]\\d*)(?:\\.\\d*)?$"
        //REGEX_FOR_INTEGERS  @"^([+-]?)(?:|0|[1-9]\\d*)?$"
        //        let phoneNumberRegEx = "^([+-]?)(?:|0|[1-9]\\d*)(?:\\.\\d*)?$"//"[0-9]"//"[235689][0-9]{6}([0-9]{3})?"
        //        let pnTest = NSPredicate(format:"SELF MATCHES %@", phoneNumberRegEx)
        //        let result = pnTest.evaluate(with: self)
        //        return result
        do {
            let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue)
            let matches = detector.matches(in: self, options: [], range: NSMakeRange(0, self.count))
            if let res = matches.first {
                return res.resultType == .phoneNumber && res.range.location == 0 && res.range.length == self.count && self.count == 10
            } else {
                return false
            }
        } catch {
            return false
        }
    }
    
    //Trim white sapces from string
    func trimWhiteSpace() -> String {
        return self.trimmingCharacters(in: NSCharacterSet.whitespaces)
    }
}

extension String: LocalizedError {
    public var errorDescription: String? { return self }
}

// Extension for Hex2ByteArray
// https://stackoverflow.com/questions/43360747/how-to-convert-hexadecimal-string-to-an-array-of-uint8-bytes-in-swift

extension String {
    var hexa2Bytes: [UInt8] {
        let hexa = Array(self)
        return stride(from: 0, to: count, by: 2).compactMap { UInt8(String(hexa[$0..<$0.advanced(by: 2)]), radix: 16) }
    }
}

extension String {
    public func getDomain() -> String? {
        guard let url = URL(string: self) else { return nil }
        return url.host
    }
}

extension String {
    
    func substring(_ from: Int) -> String {
        let start = index(startIndex, offsetBy: from)
        return String(self[start ..< endIndex])
    }
}

extension Array where Element: Equatable {
    
    // Remove first collection element that is equal to the given `object`:
    mutating func remove(object: Element) {
        if let index = index(of: object) {
            remove(at: index)
        }
    }
}

extension Double
{
    func truncate(places : Int)-> Double
    {
        return Double(floor(pow(10.0, Double(places)) * self)/pow(10.0, Double(places)))
    }
}

extension Float
{
    var cleanValue: String
    {
        return String(format: "%.0f", self)
    }
}

extension URL {
    var attributes: [FileAttributeKey : Any]? {
        do {
            return try FileManager.default.attributesOfItem(atPath: path)
        } catch let error as NSError {
            print("FileAttribute error: \(error)")
        }
        return nil
    }
    
    var fileSize: UInt64 {
        return attributes?[.size] as? UInt64 ?? UInt64(0)
    }
    
    var creationDate: Date? {
        return attributes?[.creationDate] as? Date
    }
}

extension String {
    var utf8Array: [UInt8] {
        return Array(utf8)
    }
}

extension String
{
    public func toDateTime() -> Date?
    {
        //Create Date Formatter
        let dateFormatter = DateFormatter()
        
        //Specify Format of String to Parse
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZ"
        
        //Parse into NSDate
        if let date = dateFormatter.date(from: self){
            return date
        }else{
            print("Date parsing error \(self)")
        }
        //Return Parsed Date
        return nil
    }
}
