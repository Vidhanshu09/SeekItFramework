//
//  TATrackerModel.swift
//  SeekLib
//
//  Created by Jitendra Chamoli on 09/10/18.
//

import Foundation
import SwiftyJSON
import CocoaLumberjack

public enum SensorType: Int {
    case Wallet
    case keys
    case Carkeys
    case Child
    case Handbag
    case Briefcase
    case Phone
}

public class TASensorList: NSObject {
    
    public var sensorArray:[TASensor]?
    
    override init(){
    }
    
    required public init (listArray: JSON) {
        
        self.sensorArray = [TASensor]()
        
        if listArray.count > 0 {
            for item in listArray.array! {
                let sensor = TASensor(sensorDict: item)
                
                let newDev:TrackersInfo = TrackersInfo()
                if let currentLoggedInUsersEmail = UserDefaults.standard.string(forKey: AppConstants.userEmailKey) {
                    newDev.userEmail = currentLoggedInUsersEmail
                }
                if let sensorID = sensor.UUID, let userID = UserDefaults.standard.string(forKey: AppConstants.userIDKey) {
                    newDev.deviceId = "\(sensorID)\(userID)"
                }
                if let sensorName = sensor.trackerName {
                    newDev.deviceName = sensorName
                }
                if let sharedState = sensor.sharedState {
                    newDev.sharedState = sharedState
                }
                if let sharedUserID = sensor.sharedUserId {
                    newDev.sharedUserID  = sharedUserID
                }
                if let passKey = sensor.passKey {
                    newDev.passKey = passKey.stringValue
                }
                if let alertMode = sensor.alertMode {
                    newDev.alertMode.value = alertMode.intValue
                }
                if let pickPocketMode = sensor.pickPocketMode {
                    newDev.pickPocketMode = pickPocketMode
                }
                if let trackerBuzzTime = sensor.buzzTime {
                    newDev.buzzDuration.value = trackerBuzzTime.intValue
                }
                if let trackerModelNumber = sensor.modelNumber {
                    newDev.deviceModelNumber = trackerModelNumber
                }
                if let trackerSerialNumber = sensor.serialNumber {
                    newDev.deviceSerialNumber = trackerSerialNumber
                }
                if let trackerfirmwareVersion = sensor.deviceFirmwareVersion {
                    newDev.firmwareVersion = trackerfirmwareVersion
                }
                if let trackerHardwareRevision = sensor.hardwareRevision {
                    newDev.deviceHardwareRevision = trackerHardwareRevision
                }
                if let lostMode = sensor.lostMode {
                    newDev.lostMode.value = lostMode.intValue
                }
                if let distanceToDisconnect = sensor.distanceToDisconnect {
                    newDev.distanceToDisconnect = "\(distanceToDisconnect)"
                }
                if let pictureURL = sensor.pictureURL {
                    newDev.deviceImageURL = pictureURL
                }
                if let trackerRingURL = sensor.customRingtoneURL {
                    newDev.deviceRingURL = trackerRingURL
                }
                if let trackerRingName = sensor.ringToneName {
                    newDev.deviceRingName = trackerRingName
                }
                if let trackerCatName = sensor.category {
                    newDev.deviceCategory = trackerCatName
                }
                if let trackerType = sensor.type {
                    newDev.trackerType.value = trackerType.intValue
                }
                // Set AutoConnect
                newDev.autoConnect = sensor.autoConnect
                DispatchQueue.main.async {
                    SLRealmManager.sharedInstance.writeDeviceRecord(device: newDev)
                }
                self.sensorArray?.append(sensor)
            }
        }
    }
}

public class TASensor: NSObject {
    
    public var UUID: String?
    public var trackerName: String?
    public var sharedState: Bool?
    public var autoConnect : Bool = true
    public var sharedUserId: String?
    public var distanceToDisconnect: NSNumber?
    public var passKey: NSNumber?
    public var alertMode: NSNumber?
    public var weight: NSNumber?
    public var buzzTime: NSNumber?
    public var pickPocketMode: Bool?
    public var modelNumber: String?
    public var hardwareRevision: String?
    
    public var lostMode: NSNumber?
    public var pictureURL: String?
    public var customRingtoneURL: String?
    public var ringToneName: String?
    public var type: NSNumber?
    public var category: String?
    public var serialNumber:String?
    
    // *** Additional Fields - Updated when sensor is nearby **  //
    public var firstTimeDelay: Bool = false
    public var isDeviceBuzzingDelay: Bool = false
    public var deviceFirmwareVersion: String?
    public var connectionStatus : String?
    public var batteryLevel: UInt8?
    public var isBuzzing : Bool = false
    public var trackerType:SensorType = .Phone
    
    // *** Additional Fields - Updated when sensor upgrade is initiated **  //
    public var progressLabel: String?
    public var uploadStatus: String? {
        didSet {
            if let uuid = UUID {
                UserDefaults.standard.set(uploadStatus, forKey: "\(uuid)-DFUStatus")
                UserDefaults.standard.synchronize()
            }
        }
    }
    
    public override init() {
    }
    
    required public init (sensorDict: JSON) {
        
        if let trackerId = sensorDict["UUID"].string {
            self.UUID = trackerId
            if let userID = UserDefaults.standard.string(forKey: AppConstants.userIDKey), let deviceRecord = SLRealmManager.sharedInstance.readDeviceRecords().filter({ $0.deviceId == "\(trackerId)\(userID)" }).first {
                if let lastBatteryValue = deviceRecord.batteryLevel.value {
                    batteryLevel = UInt8(lastBatteryValue)
                }
                print(deviceRecord.deviceModelNumber)
                deviceFirmwareVersion = deviceRecord.firmwareVersion
                modelNumber = deviceRecord.deviceModelNumber
                autoConnect = deviceRecord.autoConnect
            }
            if let uploadStatus = UserDefaults.standard.string(forKey: "\(trackerId)-DFUStatus"), uploadStatus != "Upload complete", SLSensorManager.sharedInstance.updatingDFUDevice == false{
                self.uploadStatus = uploadStatus
                self.progressLabel = "Upload Failed"
            }
        }
        if let trackerName = sensorDict["trackerName"].string {
            self.trackerName = trackerName
        }
        if let sharedState = sensorDict["sharedState"].number {
            self.sharedState = sharedState.boolValue
        }
        if let autoConnectState = sensorDict["autoConnect"].number {
            self.autoConnect = autoConnectState.boolValue
        }
        if let sharedUserID = sensorDict["sharedUserId"].number {
            self.sharedUserId = sharedUserID.stringValue
        }
        if let distanceForDisconnect = sensorDict["distanceToDisconnect"].number {
            self.distanceToDisconnect = distanceForDisconnect
        }
        if let trackerAlertMode = sensorDict["alertMode"].number {
            self.alertMode = trackerAlertMode
        }
        if let trackerBuzzTime = sensorDict["toneLength"].number {
            self.buzzTime = trackerBuzzTime
        }
        if let trackerPicPocketMode = sensorDict["pickPocketMode"].number {
            self.pickPocketMode = trackerPicPocketMode.boolValue
        }
        //if let modelNumber = sensorDict["modelNumber"].string {
        //self.modelNumber = modelNumber
        //            print(sensorDict["category"])
        //            print(self.modelNumber)
        //            if modelNumber == "Wallet" {
        //                self.trackerType = .Wallet
        //            } else if modelNumber == "keys"{
        //                self.trackerType = .keys
        //            }else if modelNumber == "Carkeys"{
        //                self.trackerType = .Carkeys
        //            }else if modelNumber == "Child"{
        //                self.trackerType = .Child
        //            }else if modelNumber == "Handbag"{
        //                self.trackerType = .Handbag
        //            }else if modelNumber == "Briefcase"{
        //                self.trackerType = .Briefcase
        //            }else{
        //                self.trackerType = .Phone
        //            }
        //}
        if let hardwareRevision = sensorDict["hardwareVersion"].string {
            self.hardwareRevision = hardwareRevision
        }
        if let trackerMode = sensorDict["mode"].number {
            //print(connectionStatus)
            if trackerMode == 2 {
                connectionStatus = "lost"
            } else {
                connectionStatus = "disconnected"
            }
            self.lostMode = trackerMode
        }
        if let device = SLCloudConnector.sharedInstance.devicesList?.sensorArray?.filter( { $0.UUID == sensorDict["UUID"].string }).first {
            self.connectionStatus = device.connectionStatus
        }
        if let trackerWeight = sensorDict["weight"].number {
            self.weight = trackerWeight
        }
        if let firmwareString = sensorDict["firmwareString"].string {
            self.deviceFirmwareVersion = firmwareString
        }
        if let pairingCode = sensorDict["passKey"].number {
            self.passKey = pairingCode
        }
        if let trackerImageURL = sensorDict["imageUrl"].string {
            self.pictureURL = trackerImageURL
        }
        if let trackerRingURL = sensorDict["ringToneUrl"].string {
            self.customRingtoneURL = trackerRingURL
            //DDLogVerbose("Retrieved Audio for \(String(describing: trackerName)):- \(trackerRingURL)")
            if let _ = SLRealmManager.sharedInstance.readAllAudioCache().filter({ $0.serverURL == trackerRingURL }).first {
            } else {
                if trackerRingURL.count > 1 {
                    // Download Audio for caching
                    AudioManager.shared.retrieveAudio(for: trackerRingURL)
                }
            }
        }
        if let trackerRingName = sensorDict["ringToneName"].string {
            self.ringToneName = trackerRingName
        }
        if let trackerCategory = sensorDict["category"].string {
            self.category = trackerCategory
        }
        if let trackerType = sensorDict["type"].number {
            self.type = trackerType
            self.trackerType = SensorType(rawValue: trackerType.intValue) ?? .Phone
        }
        if let trackerSerialNumber = sensorDict["serialNumber"].string {
            self.serialNumber = trackerSerialNumber
        }
    }
}
