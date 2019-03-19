//
//  TASleepModel.swift
//  SeekLib
//
//  Created by Jitendra Chamoli on 09/10/18.
//

import Foundation
import SwiftyJSON

public class TASleepModel: NSObject {

    public var startDNDTime: Date?
    public var endDNDTime: Date?
    public var isDNDEnabled: Bool = false
    public var isWeekEndEnabled: Bool = false
    public var startHour:Int?
    public var startMinutes: Int?
    public var endHour: Int?
    public var endMinutes: Int?
    public var dateSelection: String = ""
    public var suSelect: Bool = false
    public var moSelect: Bool = false
    public var tuSelect: Bool = false
    public var weSelect: Bool = false
    public var thSelect: Bool = false
    public var frSelect: Bool = false
    public var saSelect: Bool = false

    override init() {
    }

    required public init (sleepDict: JSON) {

        let sleepModel = SleepInfo()

        if let userID = SLCloudConnector.sharedInstance.userProfile?.userId {
            sleepModel.userID = userID.stringValue
        }
        if let isEnabled = sleepDict["isDnd"].number {
            self.isDNDEnabled = isEnabled == 1 ? true : false
            sleepModel.isSleepEnabled = isEnabled == 1 ? true : false
        }
        if let isWeekEnd = sleepDict["weekendMode"].number {
            self.isWeekEndEnabled = isWeekEnd == 1 ? true : false
            sleepModel.isSleepEnabled = isWeekEnd == 1 ? true : false
        }
        if let weekDays = sleepDict["weekDays"].string {
            print("Week Days============ \(weekDays) ==================")
            let days:[String] = weekDays.components(separatedBy: ",")
            self.dateSelection = weekDays
            for day in days {
                switch day {
                    case "sun":
                        self.suSelect = true
                    case "mon":
                        self.moSelect = true
                    case "tue":
                        self.tuSelect = true
                    case "wed":
                        self.weSelect = true
                    case "thu":
                        self.thSelect = true
                    case "fri":
                        self.frSelect = true
                    case "sat":
                        self.saSelect = true
                    default:
                        print("Nothing")
                }
            }
            sleepModel.saSelect = self.saSelect
            sleepModel.moSelect = self.moSelect
            sleepModel.tuSelect = self.tuSelect
            sleepModel.weSelect = self.weSelect
            sleepModel.thSelect = self.thSelect
            sleepModel.frSelect = self.frSelect
            sleepModel.saSelect = self.saSelect
            sleepModel.dateSelection = self.dateSelection
        }
        if let epotchStartTime = sleepDict["startDndTime"].string {

            if let myInteger = Int64(epotchStartTime) {
                let startTime = NSNumber(value:myInteger)

                let timeAsInterval: TimeInterval = Double(truncating: startTime)/1000
                let date = Date.init(timeIntervalSince1970: timeAsInterval)
                self.startDNDTime = date.toLocalTime()
                self.startDNDTime = date
                let calendar = Calendar.current
                self.startHour = calendar.component(.hour, from: date)
                self.startMinutes = calendar.component(.minute, from: date)

                sleepModel.sleepStartDate = date

            } else if let myInteger = Double(epotchStartTime) {

                let timeAsInterval: TimeInterval = Double(truncating: NSNumber.init(value: myInteger))/1000
                let date = Date.init(timeIntervalSince1970: timeAsInterval)
                //self.startDNDTime = date
                self.startDNDTime = date.toLocalTime()
                self.startDNDTime = date
                let calendar = Calendar.current
                self.startHour = calendar.component(.hour, from: date)
                self.startMinutes = calendar.component(.minute, from: date)
                sleepModel.sleepStartDate = date
            }
        }
        if let epotchEndTime = sleepDict["endDndTime"].string {

            if let myInteger = Int64(epotchEndTime) {
                let endTime = NSNumber(value:myInteger)
                let timeAsInterval: TimeInterval = Double(truncating: endTime)/1000
                let date = Date.init(timeIntervalSince1970: timeAsInterval)
                self.endDNDTime = date.toLocalTime()
                self.endDNDTime = date
                let calendar = Calendar.current
                self.endHour = calendar.component(.hour, from: date)
                self.endMinutes = calendar.component(.minute, from: date)

                sleepModel.sleepEndDate = date

            } else if let myInteger = Double(epotchEndTime) {
                let timeAsInterval: TimeInterval = Double(truncating: NSNumber.init(value: myInteger))/1000
                let date = Date.init(timeIntervalSince1970: timeAsInterval)
                self.endDNDTime = date.toLocalTime()
                self.endDNDTime = date
                let calendar = Calendar.current
                self.endHour = calendar.component(.hour, from: date)
                self.endMinutes = calendar.component(.minute, from: date)

                sleepModel.sleepEndDate = date
            }
        }
        DispatchQueue.main.async {
            SLRealmManager.sharedInstance.writeSleepRecord(sleepInfo: sleepModel)
        }
    }
}
