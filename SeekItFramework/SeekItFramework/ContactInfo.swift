//
//  ContactInfo.swift
//  SeekLib
//
//  Created by Jain, Rahul on 18/12/18.
//  Copyright © 2018 Wavenet Solutions. All rights reserved.
//

import Foundation
import RealmSwift

@objcMembers public class ContactInfo: Object {
    
    public enum Property: String {
        case emailId, mobileNo, loginType, countryCode
    }
    
    dynamic public var emailId = ""
    dynamic public var mobileNo = ""
    dynamic public var loginType = ""
    dynamic public var countryCode = ""

    
    // Specify properties to ignore (Realm won't persist these)
    override public static func ignoredProperties() -> [String] {
        return []
    }
    
    override public static func primaryKey() -> String? {
        return ContactInfo.Property.emailId.rawValue
    }
}
