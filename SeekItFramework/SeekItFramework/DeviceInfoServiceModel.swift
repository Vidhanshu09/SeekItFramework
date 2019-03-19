//
//  DeviceInfoServiceModel.swift
//  SeekLib
//
//  Created by Jitendra Chamoli on 09/10/18.
//

import Foundation
import CocoaLumberjack

public struct DeviceInfoServiceModelConstants {
    static let serviceUUID              = "180A"
    static let ModelNumberUUID          = "2A24"
    static let HardwareRevisionUUID     = "2A27"
    static let FirmwareRevisionUUID     = "2A26"
    static let SoftwareRevisionUUID     = "2A28"
    static let ManufacturerNameUUID     = "2A29"
    static let SerialNumberUUID         = "2A25"
    static let PairCodeUUID             = "DDD1" // Move it to New Service
    static let PowerSavingOnDeleteUUID  = "2CCC" // Move it to new Service
    //* Write pass code Pairing Code within 30 seconds after connecting
    //* New Device Information Service -> DDD1 - Pass key Service Characteristics
    //* Firmware version | Software Version
    //* Delete Device -> 2CCC -> Mandatory Write Zero before disconnecting (power saving mode) -> Stops advertisement -> Single tap wakeup
    //* Mandatory to write Pairing Passcode, Otherwise device will be Disconnected automatically
}

/**
 DeviceInfoServiceModel represents the Device Information and Pairing Auth CBService.
 */
public class DeviceInfoServiceModel: ServiceModel {
    
    public var pairCodeValue: String = ""
    public var firmwareVersion: String = ""
    public var modelNumber:String = ""
    public var hardwareRevision:String = ""
    
    //var powerSavingModeValue: UInt8 = 0
    
    override public var serviceUUID:String {
        return DeviceInfoServiceModelConstants.serviceUUID
    }
    
    override public func mapping(_ map: Map) {
        firmwareVersion     <- map[DeviceInfoServiceModelConstants.FirmwareRevisionUUID]
        hardwareRevision    <- map[DeviceInfoServiceModelConstants.HardwareRevisionUUID]
        modelNumber         <- map[DeviceInfoServiceModelConstants.ModelNumberUUID]
        pairCodeValue       <- map[DeviceInfoServiceModelConstants.PairCodeUUID]
        //powerSavingModeValue <- map[DeviceInfoServiceModelConstants.PowerSavingOnDeleteUUID]
    }
    
    override public func registerNotifyForCharacteristic(withUUID uuid: String) -> Bool {
        return false
        //return (uuid == DeviceInfoServiceModelConstants.FirmwareRevisionUUID || uuid == DeviceInfoServiceModelConstants.HardwareRevisionUUID || uuid == DeviceInfoServiceModelConstants.PairCodeUUID)
    }
    
    override public func characteristicBecameAvailable(withUUID uuid: String) {
        guard uuid == DeviceInfoServiceModelConstants.FirmwareRevisionUUID || uuid == DeviceInfoServiceModelConstants.HardwareRevisionUUID || uuid == DeviceInfoServiceModelConstants.ModelNumberUUID || uuid == DeviceInfoServiceModelConstants.PairCodeUUID else {
            return
        }
        switch uuid {
        case DeviceInfoServiceModelConstants.FirmwareRevisionUUID:
            readValue(withUUID: DeviceInfoServiceModelConstants.FirmwareRevisionUUID)
            DDLogVerbose("FDSLog:- DeviceInfoServiceModelConstants.FirmwareRevisionUUID Available")
            break
        case DeviceInfoServiceModelConstants.HardwareRevisionUUID:
            readValue(withUUID: DeviceInfoServiceModelConstants.HardwareRevisionUUID)
            DDLogVerbose("FDSLog:- DeviceInfoServiceModelConstants.HardwareRevisionUUID Available")
            break
        case DeviceInfoServiceModelConstants.ModelNumberUUID:
            readValue(withUUID: DeviceInfoServiceModelConstants.ModelNumberUUID)
            DDLogVerbose("FDSLog:- DeviceInfoServiceModelConstants.ModelNumberUUID Available")
            break
        case DeviceInfoServiceModelConstants.PairCodeUUID:
            //DDLogVerbose("FDSLog:- *** ACTION REQUIRED ** FDS ERROR *** PAIRCODE WRITE AVAILABLE IN DEVICE INFO SERVICE **")
            DDLogVerbose("FDSLog:- DeviceInfoServiceModelConstants.PairCodeUUID Available")
            readValue(withUUID: DeviceInfoServiceModelConstants.PairCodeUUID)
            break
        default:
            break
        }
    }
    
    override public func characteristicDidUpdateValue(withUUID uuid: String) {
        /*guard uuid == DeviceInfoServiceModelConstants.FirmwareRevisionUUID else {
         return
         }*/
        guard uuid == DeviceInfoServiceModelConstants.FirmwareRevisionUUID || uuid == DeviceInfoServiceModelConstants.HardwareRevisionUUID || uuid == DeviceInfoServiceModelConstants.ModelNumberUUID || uuid == DeviceInfoServiceModelConstants.PairCodeUUID else {
            return
        }
        guard let peripheralUUID = self.serviceModelManager?.peripheral?.identifier.uuidString  else {
            return
        }
        switch uuid {
        case DeviceInfoServiceModelConstants.FirmwareRevisionUUID:
            DDLogVerbose("Sensor Firmware Version: - \(firmwareVersion)")
            getFirmwareVersionFor(peripheralUUID: peripheralUUID)
            break
        case DeviceInfoServiceModelConstants.HardwareRevisionUUID:
            DDLogVerbose("Sensor Firmware Hardware Revision: - \(hardwareRevision)")
            break
        case DeviceInfoServiceModelConstants.ModelNumberUUID:
            DDLogVerbose("Sensor Firmware Model Number: - \(modelNumber)")
            break
        case DeviceInfoServiceModelConstants.PairCodeUUID:
            //DDLogVerbose("*** ACTION REQUIRED ** FDS ERROR *** PAIRCODE WRITE AVAILABLE IN DEVICE INFO SERVICE **")
            DDLogVerbose("Sensor Firmware Pass Key: - \(pairCodeValue)")
            //fixFSDErrorFor(peripheralUUID: peripheralUUID)
            break
        default:
            break
        }
        if let peripheralUUID = self.serviceModelManager?.peripheral?.identifier.uuidString {
            getFirmwareVersionFor(peripheralUUID: peripheralUUID)
        }
    }
}

extension DeviceInfoServiceModel {
    
    func getFirmwareVersionFor(peripheralUUID:String) {
        var targetUUID: String = ""
        SLSensorManager.sharedInstance.foundDevices.filter({ $0.basePeripheral.identifier.uuidString == peripheralUUID }).forEach { connectedSensor in
            targetUUID = String(connectedSensor.trackerUUID.prefix(18))
            //device = connectedSensor
        }
        SLCloudConnector.sharedInstance.devicesList?.sensorArray?.filter({ $0.UUID == targetUUID }).forEach { foundSensor in
            foundSensor.deviceFirmwareVersion = self.firmwareVersion
            foundSensor.modelNumber = self.modelNumber
            DispatchQueue.main.async {
                if let userID = UserDefaults.standard.string(forKey: AppConstants.userIDKey),
                    let deviceRecord = SLRealmManager.sharedInstance.readDeviceRecords().filter({ $0.deviceId == "\(foundSensor.UUID!)\(userID)" }).first,
                    self.firmwareVersion.count > 1 {
                    try! SLRealmManager.sharedInstance.realm.write {
                        foundSensor.deviceFirmwareVersion = self.firmwareVersion
                        deviceRecord.firmwareVersion = self.firmwareVersion
                        deviceRecord.deviceModelNumber = self.modelNumber
                    }
                }
            }
            // Check if any device has pending firmware update
            if self.firmwareVersion.count > 1, self.firmwareVersion.count > 1, self.firmwareVersion != SLCloudConnector.sharedInstance.latestFirmwareVersion {
                // Send a Post Notification to trigger firmware update
                // DFU Update is pending connected device.
                // Show Alert for Madatory Update
                NotificationCenter.default.post(
                    name: Notification.Name(rawValue: ManagerConstants.pendingFirmwareUpdtNotifyKey), object: nil, userInfo: nil)
            }
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name(rawValue: ManagerConstants.refreshStatusKey), object: nil, userInfo: nil)
            }
        }
    }
    
    func fixFSDErrorFor(peripheralUUID:String) {
        var targetUUID: String = ""
        SLSensorManager.sharedInstance.foundDevices.filter({ $0.basePeripheral.identifier.uuidString == peripheralUUID }).forEach { connectedSensor in
            targetUUID = String(connectedSensor.trackerUUID.prefix(18))
            
            //        // Make Call to get Firmware Version of this device
            //        CloudConnector.sharedInstance.getTrackerDetail(trackerUUID: targetUUID, success: { successResponse in
            //
            //        }) { failureResponse in
            //
            //        }
            
            SLCloudConnector.sharedInstance.devicesList?.sensorArray?.filter({ $0.UUID == targetUUID }).forEach { foundSensor in
                //foundSensor.deviceFirmwareVersion = self.firmwareVersion
                DispatchQueue.main.async {
                    if let tModelNumber = foundSensor.modelNumber, let tHardwareRevision = foundSensor.hardwareRevision {
                        DDLogVerbose("FDSLog:- About to write Hardware Revision \(tHardwareRevision), Model Number \(tModelNumber) in device \(String(describing: foundSensor.trackerName))")
                        connectedSensor.writeFixFSDError(hardwareRevision: tHardwareRevision, modelNumber: tModelNumber)
                    }
                }
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: Notification.Name(rawValue: ManagerConstants.refreshStatusKey), object: nil, userInfo: nil)
                }
            }
        }
    }
}
