//
//  TrackerLog.swift
//  SeekLib
//
//  Created by Jitendra Chamoli on 09/10/18.
//

import Foundation
import RealmSwift

@objcMembers public class TrackerLog: Object {
    
    public enum Property: String {
        case eventId, trackerUUID, eventType, eventDate
    }
    
    dynamic public var eventId = ""
    dynamic public var trackerUUID = ""
    dynamic public var eventType = ""
    dynamic public var eventDate: Date?
    
    // Specify properties to ignore (Realm won't persist these)
    override public static func ignoredProperties() -> [String] {
        return []
    }
    
    override public static func primaryKey() -> String? {
        return TrackerLog.Property.eventId.rawValue
    }
}
