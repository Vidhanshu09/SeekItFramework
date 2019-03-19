//
//  BatteryServiceModel.swift
//  SeekLib
//
//  Created by Jitendra Chamoli on 09/10/18.
//

import Foundation
import CocoaLumberjack

public struct BatteryServiceModelConstants {
    static let serviceUUID = "180F"
    static let batteryLevelUUID = "2A19"
    
    // Subscribe to BatteryLevel Characteristics
}

/**
 BatteryServiceModel represents the Battery CBService.
 */
public class BatteryServiceModel: ServiceModel {
    
    weak public var delegate: BatteryServiceModelDelegate?
    public var batteryLevel: UInt8 = 0
    
    override open var serviceUUID:String {
        return BatteryServiceModelConstants.serviceUUID
    }
    
    override public func mapping(_ map: Map) {
        batteryLevel <- map[BatteryServiceModelConstants.batteryLevelUUID]
    }
    
    override public func characteristicBecameAvailable(withUUID uuid: String) {
        readValue(withUUID: uuid)
    }
    
    override public func registerNotifyForCharacteristic(withUUID uuid: String) -> Bool {
        return uuid == BatteryServiceModelConstants.batteryLevelUUID
    }
    
    override public func characteristicDidUpdateValue(withUUID uuid: String) {
        guard uuid == BatteryServiceModelConstants.batteryLevelUUID else {
            return
        }
        
        DispatchQueue.main.async {
            if let peripheralUUID = self.serviceModelManager?.peripheral?.identifier.uuidString {
                //self.delegate?.batteryLevelChanged(self.batteryLevel, peripheralUUID: peripheralUUID)
                self.batteryLevelChanged(self.batteryLevel, peripheralUUID: peripheralUUID)
            }
        }
    }
    
    func batteryLevelChanged(_ batteryLevel: UInt8, peripheralUUID: String) {
        var targetUUID: String = ""
        SLSensorManager.sharedInstance.foundDevices.filter({ $0.basePeripheral.identifier.uuidString == peripheralUUID }).forEach { connectedSensor in
            targetUUID = String(connectedSensor.trackerUUID.prefix(18))
            DDLogVerbose("\(String(describing: connectedSensor.basePeripheral.name!)) -> battery level:- \(batteryLevel)%")
        }
        SLCloudConnector.sharedInstance.devicesList?.sensorArray?.filter({ $0.UUID == targetUUID }).forEach { foundSensor in
            foundSensor.batteryLevel = batteryLevel
            DispatchQueue.main.async {
                if let userID = UserDefaults.standard.string(forKey: AppConstants.userIDKey), let deviceRecord = SLRealmManager.sharedInstance.readDeviceRecords().filter({ $0.deviceId == "\(foundSensor.UUID!)\(userID)" }).first {
                    try! SLRealmManager.sharedInstance.realm.write {
                        deviceRecord.batteryLevel.value = Int(batteryLevel)
                    }
                }
                DDLogVerbose("Reload table due to battery level change")
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: Notification.Name(rawValue: ManagerConstants.refreshStatusKey), object: nil, userInfo: nil)
                }
            }
        }
    }
}


public protocol BatteryServiceModelDelegate: class {
    func batteryLevelChanged(_ batteryLevel: UInt8, peripheralUUID:String)
}
