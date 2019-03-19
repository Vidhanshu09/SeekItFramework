//
//  MainServiceModel.swift
//  SeekLib
//
//  Created by Jitendra Chamoli on 09/10/18.
//

import Foundation
import CocoaLumberjack

public struct MainServiceModelConstants {
    
    static let serviceUUID          = "0000AAAA-1312-EFDE-1523-785FEF13D123"
    static let customCharUUID       = "0000AAA1-1312-EFDE-1523-785FEF13D123"
    static let debugLogCharUUID     = "0000AAA2-1312-EFDE-1523-785FEF13D123"
    static let secondCustomCharUUID = "0000AAA3-1312-EFDE-1523-785FEF13D123"
    
    // ********************************************* //
    // ********************************************* //
}

/**
 MainServiceModel represents the Main Common CBService for Ring, Alert, Led Control.
 */
public class MainServiceModel: ServiceModel {
    
    weak public var delegate: MainServiceModelDelegate?
    public var controlPoint = Data()
    public var secondControlPoint = Data()
    public var timer = Timer()
    public var seconds = 30
    public var isTimerRunning = false
    public var sensorBuzzInitiator:TrackerDevice?
    
    override public var serviceUUID:String {
        return MainServiceModelConstants.serviceUUID
    }
    
    override public func mapping(_ map: Map) {
        controlPoint        <- map[MainServiceModelConstants.customCharUUID]
        secondControlPoint  <- map[MainServiceModelConstants.secondCustomCharUUID]
    }
    
    override public func registerNotifyForCharacteristic(withUUID uuid: String) -> Bool {
        return (uuid == MainServiceModelConstants.customCharUUID || uuid == MainServiceModelConstants.secondCustomCharUUID)
    }
    
    override public func characteristicBecameAvailable(withUUID uuid: String) {
        // Reset Energy Expended via ControlPoint if needed.
        if uuid != MainServiceModelConstants.customCharUUID || uuid != MainServiceModelConstants.secondCustomCharUUID {
            return
        }
        print("Main Char and Second Char is available to write")
    }
    
    override public func characteristicDidUpdateValue(withUUID uuid: String) {
        if (uuid == MainServiceModelConstants.customCharUUID || uuid == MainServiceModelConstants.secondCustomCharUUID) {
            DDLogVerbose("customCharUUID characteristicDidUpdateValue \(controlPoint.hexString))")
            if let peripheralUUID = self.serviceModelManager?.peripheral?.identifier.uuidString {
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    NotificationCenter.default.post(
                        name: Notification.Name(rawValue: "notificationBellIcon"), object: nil, userInfo: nil)
                }
                
                print(controlPoint.hexString.prefix(4).uppercased())
                
                switch controlPoint.hexString.prefix(4).uppercased() {
                    
                case "A201":
                    DDLogVerbose("** Alert Status - TURNED ON **")
                    self.alertLevelChanged(1, peripheralUUID: peripheralUUID)
                    break
                case "A202":
                    DDLogVerbose("** Alert Status - TURNED OFF **")
                    self.alertLevelChanged(0, peripheralUUID: peripheralUUID)
                    break
                case "A301":
                    DDLogVerbose("** TURN ON CAMERA **")
                    break
                case "A302":
                    DDLogVerbose("** TURN OFF CAMERA **")
                    break
                default:
                    break
                }
                switch secondControlPoint.hexString.prefix(4).uppercased() {
                case "A303":
                    DDLogVerbose("** CAPTURE SELFIE ** \(String(describing: peripheralUUID))")
                    NotificationCenter.default.post(
                        name: Notification.Name(rawValue: ManagerConstants.takeSelfieByTrackersKey), object: nil, userInfo: nil)
                    break
                case "A401":
                    DDLogVerbose("Ring mobile")
                    DispatchQueue.main.async {
                        self.sensor2MobileChanged(alertLevel: 1, peripheralUUIDString: peripheralUUID)
                    }
                    break
                case "A105":
                    DDLogVerbose("JCTimer:- User Manually Stopped Buzz and Blink in the Sensor")
                    self.sensorStoppedBuzzing(peripheralUUIDString: peripheralUUID)
                    break
                case "A402":
                    DDLogVerbose("Send SOS Alert to My Contacts")
                    // Broadcas SOS Alert
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        NotificationCenter.default.post(
                            name: Notification.Name(rawValue: ManagerConstants.triggerSOSTriggerKey), object: nil)
                    }
                    break
                default:
                    break
                }
            }
        }
    }
}

public protocol MainServiceModelDelegate: class {
    func alertLevelChanged(_ alertLevel: UInt8, peripheralUUID:String)
}

extension MainServiceModel {
    func sensor2MobileChanged(alertLevel: UInt8, peripheralUUIDString: String) {
        var targetDevice: TrackerDevice!
        
        SLSensorManager.sharedInstance.foundDevices.filter({ $0.basePeripheral.identifier.uuidString == peripheralUUIDString }).forEach { connectedSensor in
            //if connectedSensor.basePeripheral.identifier.uuidString == peripheralUUIDString {
            targetDevice = connectedSensor
            //}
        }
        SLCloudConnector.sharedInstance.devicesList?.sensorArray?.filter({ $0.UUID == String(targetDevice.seekitUUID) }).forEach { foundSensor in
            //if foundSensor.UUID == targetDevice.trackerUUID {
            self.sensor2MobileAlert(alertLevel: alertLevel, device: targetDevice)
            if let sensorID = foundSensor.UUID, let userID = UserDefaults.standard.string(forKey: AppConstants.userIDKey) {
                DDLogVerbose("Writing Device buzz Event for Device UUID \(sensorID) userID \(userID)")
                let newLog = TrackerLog()
                newLog.eventId = UUID().uuidString
                newLog.eventDate = Date()
                newLog.trackerUUID = sensorID
                newLog.eventType = EventType.deviceBuzz.rawValue
                DispatchQueue.main.async {
                    SLRealmManager.sharedInstance.writeLog(logInfo: newLog)
                }
                //** Post Notification for Diagonistic
                //** Post Notification to notify that Ring Button bell is working fine.
                var beaconDict: [String: Any] = [:]
                beaconDict["UUID"] = sensorID
                NotificationCenter.default.post(
                    name: Notification.Name(rawValue: DiagConstants.buttonBellObserverKey), object: nil, userInfo: beaconDict)
            }
        }
    }
    
    func sensor2MobileAlert(alertLevel: UInt8, device: TrackerDevice) {

        SLCloudConnector.sharedInstance.devicesList?.sensorArray?.filter({ $0.UUID == device.seekitUUID }).forEach { registeredSensor in

            DDLogVerbose("Sensor2 Mobile Ring value recieved -> from \(String(describing: registeredSensor.trackerName!))")
            switch alertLevel {
            case 0:
                DDLogVerbose("Alert Status - No Alert")
                SLAudioPlayer.sharedInstance.stopSound()
                if isTimerRunning {
                    self.stopTimer()
                }
                break
            case 1:
                DDLogVerbose("Alert Status - High Alert")
                if isTimerRunning {
                    // Stop timer as Now traker can ring any number of times.
                    self.stopTimer()
                }
                sensorBuzzInitiator = device
                SLNotificationsManager.sharedInstance.buzzNotification(message: "\(registeredSensor.trackerName!) is trying to find you", body: "", trackerID:String(device.trackerUUID.prefix(18)), alertMode: registeredSensor.alertMode!)
                runTimer()
                SLAudioPlayer.sharedInstance.playLoopingSound(alertMode: registeredSensor.alertMode!, buzzType: "normal", ringURL: registeredSensor.customRingtoneURL ?? "", ringName: registeredSensor.ringToneName ?? "")
                break
            case 2:
                DDLogVerbose("Alert Status - Sleep Mode")
                break
            default:
                break
            }
        }
    }
    
    func sensorStoppedBuzzing(peripheralUUIDString: String) {
        var targetDevice: TrackerDevice!
        SLSensorManager.sharedInstance.foundDevices.filter({ $0.basePeripheral.identifier.uuidString == peripheralUUIDString }).forEach { connectedSensor in
            targetDevice = connectedSensor
            // Take action after Sensor Stopped buzzing
            if connectedSensor.isTimerRunning {
                // Stop timer Buzz
                connectedSensor.stopTimer()
            }
        }
        SLCloudConnector.sharedInstance.devicesList?.sensorArray?.filter({ $0.UUID == String(targetDevice.trackerUUID.prefix(18)) }).forEach { foundSensor in
            foundSensor.isBuzzing = false
            self.refreshDashboardUIForStoppedBuzzing(device: targetDevice)
        }
    }
    
    public func refreshDashboardUIForStoppedBuzzing(device: TrackerDevice) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Notification.Name(rawValue: ManagerConstants.refreshStatusKey), object: nil, userInfo: nil)
        }
    }
    
    public func runTimer() {
        timer = Timer.scheduledTimer(timeInterval: 1, target: self,   selector: (#selector(MainServiceModel.updateTimer)), userInfo: nil, repeats: true)
    }
    
    @objc func updateTimer() {
        seconds -= 1     //This will decrement(count down)the seconds.
        isTimerRunning = true
        if seconds == 0 {
            SLAudioPlayer.sharedInstance.stopSound()
            stopTimer()
        }
    }
    
    public func stopTimer() {
        timer.invalidate()
        isTimerRunning = false
        seconds = 30
        if let device = sensorBuzzInitiator {
            DDLogVerbose("Stop Buzzing from Stop Timer")
            device.stopBuzzing()
        }
    }
}

extension MainServiceModel {
    func alertLevelChanged(_ alertLevel: UInt8, peripheralUUID:String) {
        var targetUUID: String = ""
        var device:TrackerDevice!
        SLSensorManager.sharedInstance.foundDevices.filter({ $0.basePeripheral.identifier.uuidString == peripheralUUID }).forEach { connectedSensor in
            //if connectedSensor.basePeripheral.identifier.uuidString == peripheralUUID {
            targetUUID = String(connectedSensor.trackerUUID.prefix(18))
            device = connectedSensor
            DDLogVerbose("\(String(describing: connectedSensor.basePeripheral.name!)) -> alert level:- \(alertLevel)")
            //}
        }
        SLCloudConnector.sharedInstance.devicesList?.sensorArray?.filter({ $0.UUID == targetUUID }).forEach { foundSensor in
            if foundSensor.alertMode!.intValue == AppConstants.LOW_ALERT_MODE.intValue {
                DDLogVerbose("Setting LOW alert mode for \(foundSensor.trackerName!)")
                device.turnOffAlertMode(complitionHandler: { (charecterstics) in
                    print("writing turnOffAlertMode value \(String(describing: charecterstics.value))")
                })
            } else if foundSensor.alertMode!.intValue == AppConstants.HIGH_ALERT_MODE.intValue {
                DDLogVerbose("Setting HIGH alert mode for \(foundSensor.trackerName!)")
                device.turnOnAlertMode(complitionHandler: { (charecterstics) in
                    print("writing turnOnAlertMode value \(String(describing: charecterstics.value))")
                })
            }
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name(rawValue: ManagerConstants.refreshStatusKey), object: nil, userInfo: nil)
            }
        }
    }
}
