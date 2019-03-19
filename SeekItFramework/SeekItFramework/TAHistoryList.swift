//
//  TAHistoryList.swift
//  SeekLib
//
//  Created by Jitendra Chamoli on 09/10/18.
//

import Foundation
import SwiftyJSON

public class TAHistoryList: NSObject {
    
    public var historyArray:[TASensorHistory]?
    
    override init(){
    }
    
    required public init (listArray: JSON) {
        
        self.historyArray = [TASensorHistory]()
        
        if listArray.count > 0 {
            for item in listArray.array! {
                let sensor = TASensorHistory(shareDict: item)
                self.historyArray?.append(sensor)
            }
        }
    }
}

public class TASensorHistory: NSObject {
    
    public var usersArray:[TAUser]?
    public var UUID: String?
    
    override init() {
    }
    
    required public init (shareDict: JSON) {
        
        self.usersArray = [TAUser]()
        
        if let trackerUUID = shareDict["tracker"]["UUID"].string {
            self.UUID = trackerUUID
        }
        if let usersArray = shareDict["users"].array {
            if usersArray.count > 0 {
                for item in usersArray {
                    let user = TAUser(userDict: item)
                    self.usersArray?.append(user)
                }
            }
        }
    }
}

public class TAUser: NSObject {
    
    public var lastName: String?
    public var firstName: String?
    public var userID: NSNumber?
    public var emailID: String?
    public var shareTime: String?
    public var shareUTCDate: Date?
    public var unshareTime: String?
    
    override init() {
    }
    
    required public init (userDict: JSON) {
        
        if let emailID = userDict["emailId"].string {
            self.emailID = emailID
        }
        if let lastName = userDict["lastName"].string {
            self.lastName = lastName
        }
        if let userID = userDict["userId"].number {
            self.userID = userID
        }
        if let firstName = userDict["firstName"].string {
            self.firstName = firstName
        }
        if let unshareTime = userDict["unshareTime"].number {
            let timeAsInterval: TimeInterval = Double(truncating: unshareTime)/1000
            let date = Date.init(timeIntervalSince1970: timeAsInterval)
            self.shareUTCDate = date
            if unshareTime == 0{
                self.unshareTime = "0"
            }else{
                self.unshareTime = date.getElapsedInterval
            }
        }
        if let shareTime = userDict["shareTime"].number {
            let timeAsInterval: TimeInterval = Double(truncating: shareTime)/1000
            let date = Date.init(timeIntervalSince1970: timeAsInterval)
            self.shareUTCDate = date
            self.shareTime = date.getElapsedInterval
        }
    }
    
    func epochToLocal(epochTime:Double)->String{
        
        let timeResult:Double = epochTime
        let date = NSDate(timeIntervalSince1970: timeResult)
        let localDate = DateUtility.dateFormatter.string(from: date as Date)
        return "\(localDate)"
    }
}
