//
//  RingServiceModel.swift
//  SeekLib
//
//  Created by Jitendra Chamoli on 09/10/18.
//

//import Foundation
//import CocoaLumberjack
//
//public struct RingServiceModelConstants {
//    static let serviceUUID           = "0000AAAA-1312-EFDE-1523-785FEF13D123"
//    static let sensor2MobileRingUUID = "0000AAA1-1312-EFDE-1523-785FEF13D123"
//    static let mobile2SensorRingUUID = "0000AAA2-1312-EFDE-1523-785FEF13D123"
//    // Device to Mobile Ring -> Subscribe for this event
//    // Read -> 0x01 -> Ring on Mobile phone for 30 seconds and Set to 0x00
//    // ****************************************** //
//    // Action:- Single Tap in Sensor to Ring Mobile
//    // Action:- Double Tap on Sensor to make it silent
//}
//
///**
// RingServiceModel represents the Ring CBService.
// */
//class RingServiceModel: ServiceModel {
//
//    weak var delegate: RingServiceModelDelegate?
//    //var alertController = UIAlertController()
//    var timer = Timer()
//    var seconds = 30
//    var isTimerRunning = false
//    var sensorBuzzInitiator:TrackerDevice?
//    var sensor2Ring: UInt8 = 0
//    var mobile2Ring: UInt8 = 0
//
//    override var serviceUUID:String {
//        return RingServiceModelConstants.serviceUUID
//    }
//
//    override func mapping(_ map: Map) {
//        sensor2Ring     <- map[RingServiceModelConstants.sensor2MobileRingUUID]
//        mobile2Ring     <- map[RingServiceModelConstants.mobile2SensorRingUUID]
//    }
//
//    override func registerNotifyForCharacteristic(withUUID uuid: String) -> Bool {
//        return uuid == RingServiceModelConstants.sensor2MobileRingUUID
//    }
//
//    override func characteristicBecameAvailable(withUUID uuid: String) {
//        if uuid != RingServiceModelConstants.sensor2MobileRingUUID {
//            return
//        }
//        readValue(withUUID: uuid)
//    }
//
//    override func characteristicDidUpdateValue(withUUID uuid: String) {
//        if (uuid != RingServiceModelConstants.sensor2MobileRingUUID) {
//            return
//        }
//        /*DispatchQueue.main.async {
//         if let presentedVC = AppDelegate.shared.window?.rootViewController?.navigationController?.topViewController {
//         if presentedVC.isKind(of: RecordVideoViewController.self) {
//         DDLogVerbose("Prevented RingTone Alert As Camera is Open")
//         return
//         }
//         }
//         }*/
//        if let peripheralUUID = self.serviceModelManager?.peripheral?.identifier.uuidString {
//            if self.sensor2Ring == 0 {
//                DDLogVerbose("Do not ring")
//                self.sensor2MobileChanged(self.sensor2Ring, alertLevel: 0, peripheralUUIDString: peripheralUUID)
//                //            if let peripheralUUID = self.serviceModelManager?.peripheral?.identifier.uuidString {
//                //                self.sensor2MobileChanged(self.sensor2Ring, alertLevel: 0, peripheralUUIDString: peripheralUUID)
//                //            }
//            } else if self.sensor2Ring == 1 {
//                DDLogVerbose("Ring mobile")
//                //if let peripheralUUID = self.serviceModelManager?.peripheral?.identifier.uuidString {
//                DispatchQueue.main.async {
//                    //self.delegate?.sensor2MobileChanged(self.sensor2Ring, alertLevel: 1, peripheralUUIDString: peripheralUUID)
//                    self.sensor2MobileChanged(self.sensor2Ring, alertLevel: 1, peripheralUUIDString: peripheralUUID)
//                }
//                // Stop ringing after 30 seconds
//                /*DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) {
//                 // Write 0x00 in sensor2MobileRing Characteristic
//                 // Otherwise next time connect -> phone will keep ringing.
//                 self.sensor2Ring = 0
//                 //let data = Data(bytes: &self.sensor2Ring, count: 1)
//                 //self.writeValue(data, for: aCharacteristic, type: CBCharacteristicWriteType.withResponse)
//                 self.writeValue(withUUID: RingServiceModelConstants.sensor2MobileRingUUID)
//                 //self.sensor2MobileChanged(self.sensor2Ring, alertLevel: 0, peripheralUUIDString: peripheralUUID)
//                 }*/
//                //}
//            }
//        }
//    }
//
//    fileprivate func ringSensor() {
//        self.mobile2Ring = 1
//        self.writeValue(withUUID: RingServiceModelConstants.mobile2SensorRingUUID)
//    }
//
//    func sensor2MobileChanged(_ ringValue: UInt8, alertLevel: UInt8, peripheralUUIDString: String) {
//        var targetDevice: TrackerDevice!
//        SLSensorManager.sharedInstance.foundDevices.filter({ $0.basePeripheral.identifier.uuidString == peripheralUUIDString }).forEach { connectedSensor in
//            //if connectedSensor.basePeripheral.identifier.uuidString == peripheralUUIDString {
//            targetDevice = connectedSensor
//            //}
//        }
//        SLCloudConnector.sharedInstance.devicesList?.sensorArray?.filter({ $0.UUID == String(targetDevice.trackerUUID.prefix(18)) }).forEach { foundSensor in
//            //if foundSensor.UUID == targetDevice.trackerUUID {
//            self.sensor2MobileAlert(ringValue, alertLevel: alertLevel, device: targetDevice)
//            //}
//        }
//    }
//
//    func sensor2MobileAlert(_ ringValue: UInt8, alertLevel: UInt8, device: TrackerDevice) {
//
//        SLCloudConnector.sharedInstance.devicesList?.sensorArray?.filter({ $0.UUID == String(device.trackerUUID.prefix(18)) }).forEach { registeredSensor in
//            //if registeredSensor.UUID == device.trackerUUID {
//            DDLogVerbose("Sensor2 Mobile Ring value recieved -> \(ringValue) from \(String(describing: registeredSensor.trackerName!))")
//            switch alertLevel {
//            case 0:
//                DDLogVerbose("No Alert")
//                //alertController.dismiss(animated: true, completion: nil)
//                SLAudioPlayer.sharedInstance.stopSound()
//                if isTimerRunning {
//                    self.stopTimer()
//                }
//                break
//            case 1:
//                DDLogVerbose("Alert Status - High Alert")
//                sensorBuzzInitiator = device
//                SLNotificationsManager.sharedInstance.buzzNotification(message: "\(registeredSensor.trackerName!) is buzzing this device", body: "", trackerID:String(device.trackerUUID.prefix(18)), alertMode: registeredSensor.alertMode!)
//                runTimer()
//                //TAAudioPlayer.sharedInstance.playLoopingSound()
//                if UIApplication.shared.applicationState == UIApplicationState.active {
//                    // Show Alert
//                    /*if UIApplication.shared.keyWindow?.rootViewController?.presentedViewController == nil  {
//                     alertController = UIAlertController(
//                     title: "Buzz Alert",
//                     message: "\(registeredSensor.trackerName!) is buzzing this device",
//                     preferredStyle: .alert)
//
//                     let stopRingAction = UIAlertAction(title: "Stop Buzzing", style: .default) { (action) in
//                     // Stop Ringing
//                     DispatchQueue.main.async {
//                     TAAudioPlayer.sharedInstance.stopSound()
//                     SLSensorManager.sharedInstance.foundDevices.forEach({ sensor in
//                     if sensor.trackerUUID == registeredSensor.UUID {
//                     sensor.stopBuzzing()
//                     self.alertController.dismiss(animated: true, completion: nil)
//                     }
//                     })
//                     }
//                     }
//                     alertController.addAction(stopRingAction)
//                     // Show Action Required UI
//                     UIApplication.shared.keyWindow?.rootViewController?.present(alertController, animated: true, completion: nil)
//                     } else {
//                     print("Some View is already present, therefore can not present a alertview")
//                     }*/
//                }
//                break
//            case 2:
//                DDLogVerbose("Alert Status - Sleep Mode")
//                //self.playSoundOnce()
//                break
//            default:
//                break
//            }
//            // }
//        }
//    }
//
//    func runTimer() {
//        timer = Timer.scheduledTimer(timeInterval: 1, target: self,   selector: (#selector(RingServiceModel.updateTimer)), userInfo: nil, repeats: true)
//    }
//
//    @objc func updateTimer() {
//        seconds -= 1     //This will decrement(count down)the seconds.
//        //timerLabel.text = “\(seconds)” //This will update the label.
//        isTimerRunning = true
//        if seconds == 0 {
//            SLAudioPlayer.sharedInstance.stopSound()
//            stopTimer()
//        }
//    }
//    func stopTimer() {
//        timer.invalidate()
//        isTimerRunning = false
//        seconds = 30
//        if let device = sensorBuzzInitiator {
//            DDLogVerbose("Stop Buzzing from Stop Timer")
//            device.stopBuzzing()
//        }
//    }
//}
//
//protocol RingServiceModelDelegate: class {
//    func sensor2MobileChanged(_ ringValue: UInt8, alertLevel: UInt8, peripheralUUIDString: String)
//}
//
