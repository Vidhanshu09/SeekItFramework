//
//  TrackersInfo.swift
//  SeekLib
//
//  Created by Chamoli, Jitendra on 21/01/18.
//  Copyright © 2018 Wavenet Solutions. All rights reserved.
//

import Foundation
import RealmSwift

@objcMembers public class TrackersInfo: Object {
    
    public enum Property: String {
        case deviceId, deviceName, connectionStatus, deviceImageURL,
        deviceRingName, deviceRingURL, deviceModelNumber, deviceSerialNumber,
        deviceHardwareRevision, deviceUUIDString, userEmail,
        passKey, sharedUserID, buzzAckStatus, firmwareVersion, distanceToDisconnect,
        sharedState, pickPocketMode, sharedAckStatus, autoConnect
    }
    
    dynamic public var deviceUUID = ""
    dynamic public var userEmail = ""
    dynamic public var deviceId = ""
    dynamic public var deviceName = ""
    dynamic public var deviceImageURL = ""
    dynamic public var deviceRingName = ""
    dynamic public var deviceCategory = ""
    dynamic public var deviceRingURL = ""
    dynamic public var deviceModelNumber = ""
    dynamic public var deviceSerialNumber = ""
    dynamic public var deviceHardwareRevision = ""
    dynamic public var sharedUserID = ""
    dynamic public var buzzAckStatus = ""
    dynamic public var passKey = ""
    dynamic public var firmwareVersion = ""
    dynamic public var connectionStatus = ""
    dynamic public var distanceToDisconnect = ""
    dynamic public var sharedState = false
    dynamic public var pickPocketMode = false
    dynamic public var sharedAckStatus = false
    dynamic public var autoConnect = true
    
    /*@objc dynamic var deviceType: SensorT = .unknown
     @objc enum SensorT: Int {
     case unknown
     case wallet
     case keychain
     }*/
    
    public let deviceBuzzCount = RealmOptional<Int>()
    public let alertMode = RealmOptional<Int>()
    public let trackerType = RealmOptional<Int>()
    public let Category = RealmOptional<Int>()
    public let buzzDuration = RealmOptional<Int>()
    public let lostMode = RealmOptional<Int>()
    public let weight = RealmOptional<Int>()
    public let batteryLevel = RealmOptional<Int>()
    
    // Specify properties to ignore (Realm won't persist these)
    override public static func ignoredProperties() -> [String] {
        return []
    }
    
    override public static func primaryKey() -> String? {
        return TrackersInfo.Property.deviceId.rawValue
    }
}
