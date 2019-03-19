//
//  AudioCache.swift
//  SeekLib
//
//  Created by Jitendra Chamoli on 20/07/18.
//  Copyright © 2018 Wavenet Solutions. All rights reserved.
//

import Foundation
import RealmSwift

@objcMembers public class AudioCache: Object {
    
    public enum Property: String {
        case id, serverURL, localPath
    }
    
    dynamic public var id = ""
    dynamic public var serverURL = ""
    dynamic public var localPath = ""
    
    // Specify properties to ignore (Realm won't persist these)
    override public static func ignoredProperties() -> [String] {
        return []
    }
    
    override public static func primaryKey() -> String? {
        return AudioCache.Property.id.rawValue
    }
}
