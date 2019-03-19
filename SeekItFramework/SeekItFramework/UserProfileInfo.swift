//
//  UserProfileInfo.swift
//  SeekLib
//
//  Created by Chamoli, Jitendra on 21/01/18.
//  Copyright © 2018 Wavenet Solutions. All rights reserved.
//

import Foundation
import RealmSwift

@objcMembers public class UserProfileInfo: Object {
    
    public enum Property: String {
        case userID, emailId, firstName, lastName, countryCode, phoneNumber, sessionKey, pictureUrl, loginType, ringToneName
    }
    
    dynamic public var userID = ""
    dynamic public var emailId = ""
    dynamic public var firstName = ""
    dynamic public var lastName = "nil"
    dynamic public var countryCode = ""
    dynamic public var phoneNumber = ""
    dynamic public var sessionKey = ""
    dynamic public var pictureUrl = ""
    dynamic public var loginType = ""
    dynamic public var ringToneName = ""
    public let alertMode = RealmOptional<Int>()
    public let hasSetPassword = RealmOptional<Int>()
    dynamic public var alertOverrideMode = 0
    
    // Specify properties to ignore (Realm won't persist these)
    override public static func ignoredProperties() -> [String] {
        return []
    }
    
    override public static func primaryKey() -> String? {
        return UserProfileInfo.Property.userID.rawValue
    }
}
