//
//  TAUUIDModel.swift
//  PanasonicTracker
//
//  Created by Sanchit Mittal on 11/10/18.
//  Copyright © 2018 Wavenet Solutions. All rights reserved.
//

import Foundation
import SwiftyJSON

public class TAUUIDModel: NSObject {
    
    public var ownerId:NSNumber?
    public var UUID: String = ""
    
    public override init() {
    }
    
    required public init (uuidDict: JSON) {
        
        if let ownerId = uuidDict["ownerId"].number {
            self.ownerId = ownerId
        }
        if let UUID = uuidDict["UUID"].string {
            self.UUID = UUID
        }
    }
}
