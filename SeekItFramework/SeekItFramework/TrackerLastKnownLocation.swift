//
//  TrackerLastKnownLocation.swift
//  SeekLib
//
//  Created by Aviral Aggarwal on 14/11/18.
//  Copyright © 2018 Wavenet Solutions. All rights reserved.
//

import Foundation
import RealmSwift

@objcMembers public class TrackerLastKnownLocation: Object {
    
    dynamic public var sensorUUID = ""
    dynamic public var latitude: Double = 0.0
    dynamic public var longitude: Double = 0.0
    dynamic public var time = ""
    
}
