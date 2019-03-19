//
//  AlertServiceModel.swift
//  SeekLib
//
//  Created by Jitendra Chamoli on 09/10/18.
//

import Foundation
import CocoaLumberjack

public struct AlertServiceModelConstants {
    static let serviceUUID              = "0000ABCC-1312-EFDE-1523-785FEF13D123"
    static let alertLevelUUID           = "0000ABC1-1312-EFDE-1523-785FEF13D123"
    static let alertSleepDelayUUID      = "0000ABC2-1312-EFDE-1523-785FEF13D123"
    
    // Default Alert Level is - OFF - While Sensor is Connected
    // ON - 0x01
    // OFF - 0x00
    // SLEEP - 0x02 - Sleep for 15 minutes if you want to customize then sets using below:
    // ********************** Sleep Customization ********************
    // Why alertSleepDelayUUID :- Purpose is for Battery Saving
    // If AlertLevelUUID Value is Set For Sleep == 2 then we can customize time
    // Minutes - Defaut is 15 minutes once Sensor is connected
    // Wakeup tap button one time
    // Sets Sensor to sleep mode for specified timeinterval (In Minutes)
}

/**
 AlertServiceModel represents the ALERT CBService.
 */
class AlertServiceModel: ServiceModel {
    
    weak var delegate: AlertServiceModelDelegate?
    
    var alertOnOffValue: UInt8 = 1
    
    override var serviceUUID:String {
        return AlertServiceModelConstants.serviceUUID
    }
    
    override func mapping(_ map: Map) {
        alertOnOffValue     <- map[AlertServiceModelConstants.alertLevelUUID]
    }
    
    override func registerNotifyForCharacteristic(withUUID uuid: String) -> Bool {
        return uuid == AlertServiceModelConstants.alertLevelUUID
    }
    
    override func characteristicBecameAvailable(withUUID uuid: String) {
        guard uuid == AlertServiceModelConstants.alertLevelUUID else {
            return
        }
        readValue(withUUID: uuid)
    }
    
    override func characteristicDidUpdateValue(withUUID uuid: String) {
        guard uuid == AlertServiceModelConstants.alertLevelUUID else {
            return
        }
        
        if alertOnOffValue == 0 {
            DDLogVerbose("** Alert Status - TURNED OFF **")
            //return
        } else if alertOnOffValue == 1 {
            DDLogVerbose("** Alert Status - TURNED ON **")
        } else if alertOnOffValue == 2 {
            DDLogVerbose("** Alert Status - SLEEP **")
            return
        }
        DispatchQueue.main.async {
            if let peripheralUUID = self.serviceModelManager?.peripheral?.identifier.uuidString {
                self.alertLevelChanged(self.alertOnOffValue, peripheralUUID: peripheralUUID)
            }
        }
    }
    
    func alertLevelChanged(_ alertLevel: UInt8, peripheralUUID:String) {
        var targetUUID: String = ""
        var device:TrackerDevice!
        SLSensorManager.sharedInstance.foundDevices.filter({ $0.basePeripheral.identifier.uuidString == peripheralUUID }).forEach { connectedSensor in
            targetUUID = String(connectedSensor.trackerUUID.prefix(18))
            device = connectedSensor
            DDLogVerbose("\(String(describing: connectedSensor.basePeripheral.name!)) -> alert level:- \(alertLevel)")
        }
        SLCloudConnector.sharedInstance.devicesList?.sensorArray?.filter({ $0.UUID == targetUUID }).forEach { foundSensor in
            if foundSensor.alertMode!.intValue == AppConstants.LOW_ALERT_MODE.intValue {
                DDLogVerbose("Setting LOW alert mode for \(foundSensor.trackerName!)")
                device.turnOffAlertMode(complitionHandler: { (characterstics) in
                    print("Writing turn off characterstics \(String(describing: characterstics.value))")
                })
            } else if foundSensor.alertMode!.intValue == AppConstants.HIGH_ALERT_MODE.intValue {
                DDLogVerbose("Setting HIGH alert mode for \(foundSensor.trackerName!)")
                device.turnOnAlertMode(complitionHandler: { (characterstics) in
                    print("Writing turn on characterstics \(String(describing: characterstics.value))")
                })
            }
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name(rawValue: ManagerConstants.refreshStatusKey), object: nil, userInfo: nil)
            }
        }
    }
    
    func updateTrackerInfo(sensor: TASensor, silentMode: Bool) {
        
        var updateDict: [String: Any] = [:]
        updateDict["UUID"] = sensor.UUID
        updateDict["mode"] = sensor.alertMode!.intValue
        //if sensor.alertMode == 2 { // If it was in lost mode, Mark it as found automatically
        //updateDict["mode"] = 3
        SLCloudConnector.sharedInstance.setLostMode(lostModeDict: updateDict, success: { (successDict) in
            DispatchQueue.main.async {
                DDLogVerbose("Tracker Status Updated Successfully")
                //NotificationsManager.sharedInstance.scheduleLocalNotification(message:"\(sensor.trackerName!) has been found nearby", body: "")
            }
        }) { (errorDict) in
            DispatchQueue.main.async {
                DDLogVerbose("Tracker Status update failed!!!! -> \(String(describing: errorDict?.localizedDescription))")
            }
        }
    }
}

protocol AlertServiceModelDelegate: class {
    func alertLevelChanged(_ alertLevel: UInt8, peripheralUUID:String)
}
