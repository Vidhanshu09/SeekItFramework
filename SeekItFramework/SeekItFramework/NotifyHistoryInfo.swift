//
//  NotifyHistory.swift
//  SeekLib
//
//  Created by Chamoli, Jitendra on 21/01/18.
//  Copyright © 2018 Wavenet Solutions. All rights reserved.
//

import Foundation
import RealmSwift

@objcMembers public class NotifyHistoryInfo: Object {
    
    public enum Property: String {
        case notifyId, trackerUUID, sharingStatus, readStatus, notifyDate, notifyMessage
    }
    
    dynamic public var notifyId = ""
    dynamic public var trackerUUID = ""
    dynamic public var sharingStatus = ""
    dynamic public var readStatus = ""
    dynamic public var notifyDate: Date?
    dynamic public var notifyMessage = ""
    dynamic public var notifyTitle = ""
    
    // Specify properties to ignore (Realm won't persist these)
    override public static func ignoredProperties() -> [String] {
        return []
    }
    
    override public static func primaryKey() -> String? {
        return NotifyHistoryInfo.Property.notifyId.rawValue
    }
}

