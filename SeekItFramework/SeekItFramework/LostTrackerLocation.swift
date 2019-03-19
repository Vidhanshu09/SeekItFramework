//
//  LostTrackerLocation.swift
//  SeekLib
//
//  Created by Aviral Aggarwal on 28/10/18.
//  Copyright © 2018 Wavenet Solutions. All rights reserved.
//

import Foundation
import RealmSwift

@objcMembers public class LostTrackerLocation: Object {
    
    dynamic public var sensorUUID = ""
    dynamic public var latitude = ""
    dynamic public var longitude = ""
    dynamic public var time = ""
    
}
