//
//  WifiInfo.swift
//  SeekLib
//
//  Created by Jitendra Chamoli on 31/05/18.
//  Copyright © 2018 Wavenet Solutions. All rights reserved.
//

import Foundation
import RealmSwift

@objcMembers public class WifiInfo: Object {
    
    public enum Property: String {
        case wifiBSSID, wifiLocation, wifiSSID, isEnabled
    }
    
    dynamic public var wifiBSSID = ""
    dynamic public var wifiLocation = ""
    dynamic public var wifiSSID = ""
    dynamic public var isEnabled = false
    
    // Specify properties to ignore (Realm won't persist these)
    override public static func ignoredProperties() -> [String] {
        return []
    }
    
    override public static func primaryKey() -> String? {
        return WifiInfo.Property.wifiBSSID.rawValue
    }
}
