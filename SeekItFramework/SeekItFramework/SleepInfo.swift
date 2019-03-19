//
//  SleepInfo.swift
//  SeekLib
//
//  Created by Jitendra Chamoli on 29/06/18.
//  Copyright © 2018 Wavenet Solutions. All rights reserved.
//

import Foundation
import RealmSwift

@objcMembers public class SleepInfo: Object {
    
    public enum Property: String {
        case userID, isSleepEnabled, sleepStartDate, sleepEndDate
    }
    
    dynamic public var userID = ""
    dynamic public var isSleepEnabled = false
    dynamic public var sleepStartDate:Date?
    dynamic public var sleepEndDate: Date?
    dynamic public var suSelect: Bool = false
    dynamic public var moSelect: Bool = false
    dynamic public var tuSelect: Bool = false
    dynamic public var weSelect: Bool = false
    dynamic public var thSelect: Bool = false
    dynamic public var frSelect: Bool = false
    dynamic public var saSelect: Bool = false
    dynamic public var dateSelection: String = ""
    dynamic public var isSleepOverrideEnabled: Bool = false
    
    // Specify properties to ignore (Realm won't persist these)
    override public static func ignoredProperties() -> [String] {
        return []
    }
    
    override public static func primaryKey() -> String? {
        return SleepInfo.Property.userID.rawValue
    }
}

