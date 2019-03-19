//
//  TARaiseTicketModel.swift
//  PanasonicTracker
//
//  Created by Sanchit Mittal on 26/09/18.
//  Copyright © 2018 Wavenet Solutions. All rights reserved.
//

import Foundation
import SwiftyJSON

public class TARaiseTicketList: NSObject {
    
    public var raiseTicketsArray:[TARaiseTicket]?
    
    override init() {
        
    }
    
    required public init (listArray: JSON) {
        self.raiseTicketsArray = [TARaiseTicket]()
        
        if listArray.count > 0 {
            for item in listArray.array! {
                let raiseTicket = TARaiseTicket(raiseTicketDict: item)
                self.raiseTicketsArray?.append(raiseTicket)
            }
        }
    }

}

public class TARaiseTicket: NSObject {
    
    public var referenceId: String?
    public var currentStatus: String?
    public var createdOn: Date?
    public var logs: [JSON]?
    
    override init() {
        
    }
    
    required public init (raiseTicketDict: JSON) {
        if let referenceId = raiseTicketDict["ReferenceID"].string {
            self.referenceId = referenceId
        }
        
        if let logs = raiseTicketDict["logs"].array {
            self.logs = logs
        }
        
        if let currentStatus = logs?.first?["Status"].string {
            self.currentStatus = currentStatus
        }
        if let createdOn = logs?.first?["CreatedDate"].string {
            self.createdOn = createdOn.toDateTime()
        }
    }
}
