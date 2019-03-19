//
//  CameraServiceModel.swift
//  SeekLib
//
//  Created by Jitendra Chamoli on 09/10/18.
//

import Foundation
import CocoaLumberjack

struct CameraServiceModelConstants {
    
    static let serviceUUID         = "0000CCCC-1312-EFDE-1523-785FEF13D123"
    static let cameraOnOffUUID     = "0000CCC1-1312-EFDE-1523-785FEF13D123"
    static let selfieClickUUID     = "0000CCC2-1312-EFDE-1523-785FEF13D123"
    
    // Default - Off = Camera will be turned Off
    // Default - Off = Camera Selfie Button will be turned Off
    
    // ********************************************* //
    // We have to subscribe both characterstics after connection is successful
    // Action:- When tracker button is pushed twice then mobile phone will get a notification on first characteristic(CCC1).
    // On receiving notification mobile app will open camera.
    // Then, further button push from tracker will send notification for clicking picture on Second characteristics(CCC2) till camera mode is enabled.
    // Mobile app have to write 0x00 on first characteristic(CCC1) to disable camera mode and tracker will come to normal ring mode.
    
    // ****************************************** //
    // In second Case,
    // Action:- When user open camera from mobile app, then you have to write 0x01 on first characteristics(CCC1) to enable camera mode.
    // and on every notification from second characteristics(CCC2) mobile app will click picture.
    // To disable camera mode, mobile app will write 0x00 on first characteristics(CCC1).
}

/**
 CameraServiceModel represents the Camera CBService.
 */
class CameraServiceModel: ServiceModel {
    
    weak var delegate: CameraServiceModelDelegate?
    
    var cameraOnOffValue: UInt8 = 0
    var selfieTriggerValue: UInt8 = 0
    
    override var serviceUUID:String {
        return CameraServiceModelConstants.serviceUUID
    }
    
    override func mapping(_ map: Map) {
        cameraOnOffValue    <- map[CameraServiceModelConstants.cameraOnOffUUID]
        selfieTriggerValue  <- map[CameraServiceModelConstants.selfieClickUUID]
    }
    
    override func registerNotifyForCharacteristic(withUUID uuid: String) -> Bool {
        return true
        //uuid == CameraServiceModelConstants.cameraOnOffUUID ||
        //    uuid == CameraServiceModelConstants.selfieClickUUID
    }
    
    override func characteristicBecameAvailable(withUUID uuid: String) {
        if uuid == CameraServiceModelConstants.cameraOnOffUUID {
            readValue(withUUID: uuid)
        } else if uuid == CameraServiceModelConstants.selfieClickUUID {
            readValue(withUUID: uuid)
        }
    }
    
    override func characteristicDidUpdateValue(withUUID uuid: String) {
        if uuid == CameraServiceModelConstants.cameraOnOffUUID {
            if self.cameraOnOffValue == 0 {
                DDLogVerbose("** TURN OFF CAMERA **")
            } else if self.cameraOnOffValue == 1 {
                DDLogVerbose("** TURN ON CAMERA **")
                // Test Camera
                if let peripheralUUID = self.serviceModelManager?.peripheral?.identifier.uuidString {
                    //self.delegate?.alertLevelChanged(self.alertOnOffValue, peripheralUUID: peripheralUUID)
                    //self.alertLevelChanged(self.alertOnOffValue, peripheralUUID: peripheralUUID)
                    var infoDict:[String:Any] = [:]
                    infoDict["UUID"] = peripheralUUID
                    //DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: Notification.Name(rawValue: ManagerConstants.openCameraByTrackersKey), object: nil, userInfo: infoDict)
                    //}
                }
                /*DispatchQueue.main.async {
                 // DO SOME ACTION WHEN CAMERA IS TURNED ON..
                 // TODO:-
                 //self.delegate?.sensor2MobileChanged(self.sensor2Ring, alertLevel: 1)
                 }*/
            }
        } else if uuid == CameraServiceModelConstants.selfieClickUUID {
            if self.selfieTriggerValue == 0 {
                DDLogVerbose("** TURN OFF SELFIE LISTENER **")
            } else if selfieTriggerValue == 1 {
                DDLogVerbose("** CAPTURE SELFIE **")
            }
        }
    }
}

protocol CameraServiceModelDelegate: class {
    //func sensor2MobileChanged(_ ringValue: UInt8, alertLevel: UInt8)
}

