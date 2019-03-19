//
//  LedServiceModel.swift
//  SeekLib
//
//  Created by Jitendra Chamoli on 09/10/18.
//

import Foundation
import CocoaLumberjack

public struct LedServiceModelConstants {
    static let serviceUUID              = "0000BBBB-1312-EFDE-1523-785FEF13D123"
    static let ledOnOffLevelUUID        = "0000BBB1-1312-EFDE-1523-785FEF13D123"
    static let ledOnDelayLevelUUID      = "0000BBB2-1312-EFDE-1523-785FEF13D123"
    static let ledOffDelayLevelUUID     = "0000BBB3-1312-EFDE-1523-785FEF13D123"
    
    // Default - ON Delay   - 1 miliseconds
    // Default - OFF Delay  - 5 miliseconds
    
    // ********************************************* //
    // Turn ON/OFF LED Light on Sensor | Write 0x0 OR 0x1
    // ledOffDelayLevelUUID | Write from 0 - 10
    // ledOnDelayLevelUUID  | Write from 0 - 10
    // Action:- Tripple Tap in Sensor Image to Turn on Led Light on Sensor
    // Action:- Double Tap on Sensor to turn off LED Light
}

/**
 LedServiceModel represents the LED CBService.
 */
class LedServiceModel: ServiceModel {
    
    weak var delegate: LedServiceModelDelegate?
    
    var ledOnOffValue: UInt8 = 0
    
    override var serviceUUID:String {
        return LedServiceModelConstants.serviceUUID
    }
    
    override func mapping(_ map: Map) {
        ledOnOffValue     <- map[LedServiceModelConstants.ledOnOffLevelUUID]
    }
    
    override func registerNotifyForCharacteristic(withUUID uuid: String) -> Bool {
        return false
    }
    
    override func characteristicBecameAvailable(withUUID uuid: String) {
        if uuid != LedServiceModelConstants.ledOnOffLevelUUID {
            return
        }
        readValue(withUUID: uuid)
    }
    
    override func characteristicDidUpdateValue(withUUID uuid: String) {
        if (uuid != LedServiceModelConstants.ledOnOffLevelUUID) {
            return
        }
        if ledOnOffValue == 0 {
            DDLogVerbose("** LED STATUS - TURNED OFF **")
        } else if ledOnOffValue == 1 {
            DDLogVerbose("** LED STATUS - TURNED ON **")
            DispatchQueue.main.async {
                //self.delegate?.sensor2MobileChanged(self.sensor2Ring, alertLevel: 1)
            }
        }
    }
    
    open func blinkLed() {
        self.ledOnOffValue = 1
        self.writeValue(withUUID: LedServiceModelConstants.ledOnOffLevelUUID)
    }
}

protocol LedServiceModelDelegate: class {
    //func sensor2MobileChanged(_ ringValue: UInt8, alertLevel: UInt8)
}

