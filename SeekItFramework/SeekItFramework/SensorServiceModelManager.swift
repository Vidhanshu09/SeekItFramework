//
//  SensorServiceModelManager.swift
//  SeekLib
//
//  Created by Jitendra Chamoli on 09/10/18.
//

import Foundation
import CoreBluetooth
import CocoaLumberjack

public class SensorServiceModelManager: NSObject, CBPeripheralDelegate {
    
    fileprivate(set) weak var peripheral: CBPeripheral?
    fileprivate(set) var registeredServiceModels: [ServiceModel]
    
    // Sucessful write notification handler
    public var notifyHandler:((_ charecterstic:CBCharacteristic) -> Void)?
    
    
    // MARK: Initializers
    
    init(peripheral: CBPeripheral) {
        self.registeredServiceModels = []
        self.peripheral = peripheral
        super.init()
    }
    
    /**
     Discover all the registered services.
     Only the registered BTServiceModel subclasses will be discovered.
     */
    func discoverRegisteredServices() {
        if registeredServiceModels.count == 0 {
            return
        }
        let UUIDs = registeredServiceModels.map { CBUUID(string: $0.serviceUUID) }
        DDLogVerbose("Discovering services... for peripheral \(String(describing: peripheral?.name!))")
        peripheral?.discoverServices(UUIDs)
    }
    
    // MARK: functions
    
    /**
     
     Register a `BTServiceModel` subclass.
     - parameter serviceModel: The BTServiceModel to register.
     */
    
    func register(serviceModel: ServiceModel) {
        if !registeredServiceModels.contains(serviceModel) {
            registeredServiceModels.append(serviceModel)
            serviceModel.serviceModelManager = self
        }
    }
    
    public func setNotificationHandler(complition:@escaping (_ charecterStics:CBCharacteristic) -> Void)
    {
        notifyHandler = complition
    }
    
    /**
     Check if a specific `CBCharacteristic` is available.
     - parameter characteristicUUID: The UUID of the characteristic.
     - parameter serviceUUID: The UUID of the service.
     - returns: True if the `CBCharacteristic` is available.
     */
    
    func characteristicAvailable(_ characteristicUUID: String, serviceUUID: String) -> Bool {
        return characteristic(characteristicUUID, serviceUUID: serviceUUID) != nil
    }
    
    /**
     Perform a readValue call on the peripheral.
     
     - parameter characteristicUUID: The UUID of the characteristic.
     - parameter serviceUUID: The UUID of the service.
     */
    func readValue(_ characteristicUUID: String, serviceUUID: String) {
        if let characteristic = characteristic(characteristicUUID, serviceUUID: serviceUUID) {
            peripheral?.readValue(for: characteristic)
        }
    }
    
    /**
     Perform a writeValue call on the peripheral.
     - parameter value: The data to write.
     - parameter characteristicUUID: The UUID of the characteristic.
     - parameter serviceUUID: The UUID of the service.
     */
    func writeValue(_ value: Data, toCharacteristicUUID characteristicUUID: String, serviceUUID: String, response: Bool){
        if let characteristic = characteristic(characteristicUUID, serviceUUID: serviceUUID) {
            print(characteristic)
            peripheral?.writeValue(value, for: characteristic, type: response ? .withResponse : .withoutResponse)
        }
    }
    
    /**
     Reset all the registered BTServiceModel's.
     */
    public func resetServices() {
        for serviceModel in registeredServiceModels {
            serviceModel.resetService()
        }
    }
    
    /**
     Enables or disables notify messages for a specific characteristic / servicemodel
     
     - parameter serviceModel: The `ServiceModel`
     - parameter enabled: `Bool`
     - parameter characteristicUUID: The characteristic uuid
     */
    func setNotify(serviceModel: ServiceModel, enabled: Bool, characteristicUUID: String) {
        guard let characteristic = characteristic(characteristicUUID, serviceUUID: serviceModel.serviceUUID) else {
            return
        }
        peripheral?.setNotifyValue(enabled, for: characteristic)
    }
    
    // MARK: Private functions
    
    /**
     Get the `BTServiceModel` subclass in the the registered serviceModels.
     
     - parameter UUID: The UUID of the `BTServiceModel` to return.
     
     - returns: Returns a registered `BTServiceModel` subclass if found.
     */
    fileprivate func serviceModel(withUUID uuid: String) -> ServiceModel? {
        return registeredServiceModels.filter { $0.serviceUUID == uuid }.first
    }
    
    /**
     Get the `CBCharacteristic` with a specific UUID string of a CBService.
     
     - parameter characteristicUUID: The UUID of the `CBCharacteristic` to lookup.
     - parameter serviceUUID: The UUID of the `CBService` to lookup.
     
     - returns: A `CBCharacteristic` if found, nil if nothing found.
     */
    fileprivate func characteristic(_ characteristicUUID: String, serviceUUID: String) -> CBCharacteristic? {
        guard let service = service(withServiceUUID: serviceUUID) else {
            return nil
        }
        
        guard let characteristics = service.characteristics else {
            return nil
        }
        
        return characteristics.filter { $0.uuid.uuidString == characteristicUUID }.first
    }
    
    /**
     Get the `CBService` with a specific UUID string.
     
     - parameter serviceUUID: The UUID of the `CBService` to lookup.
     
     - returns: A `CBService` if found, nil if nothing found.
     */
    fileprivate func service(withServiceUUID serviceUUID: String) -> CBService? {
        guard let services = peripheral?.services else {
            return nil
        }
        return services.filter { $0.uuid.uuidString == serviceUUID }.first
    }
    
    // MARK: CBPeripheralDelegate
    
    @objc public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        guard error == nil else{
            DDLogVerbose("An error occured while discovering services: \(error!.localizedDescription)")
            SLSensorManager.sharedInstance.centralManager?.cancelPeripheralConnection(peripheral)
            return
        }
        
        guard let services = peripheral.services else{
            return
        }
        
        DDLogVerbose("* Service Discovery: Available Services count = \(services.count)")
        for service in services {
            //debugPrint(service.uuid.uuidString)
            // Perform discover characteristics only for registered characteristics.
            guard let serviceModel = serviceModel(withUUID: service.uuid.uuidString) else {
                continue
            }
            if service.uuid == CBUUID(string: MainServiceModelConstants.serviceUUID) {
                DDLogVerbose("* Service Discovery: Main Service found")
                let characteristics = serviceModel.characteristicUUIDs.cbUuids
                serviceModel.serviceAvailable = true
                peripheral.discoverCharacteristics(characteristics, for: service)
            } else if service.uuid == CBUUID(string: DeviceInfoServiceModelConstants.serviceUUID) {
                DDLogVerbose("* Service Discovery: Device Information Service found")
                let characteristics = serviceModel.characteristicUUIDs.cbUuids
                serviceModel.serviceAvailable = true
                peripheral.discoverCharacteristics(characteristics, for: service)
            } else if service.uuid == CBUUID(string:BatteryServiceModelConstants.serviceUUID) {
                DDLogVerbose("* Service Discovery: Battery service found")
                let characteristics = serviceModel.characteristicUUIDs.cbUuids
                serviceModel.serviceAvailable = true
                peripheral.discoverCharacteristics(characteristics, for: service)
                //            }else if service.uuid == CBUUID(string: RingServiceModelConstants.serviceUUID) {
                //                DDLogVerbose("* Service Discovery: Ring Service found")
                //                let characteristics = serviceModel.characteristicUUIDs.cbUuids
                //                serviceModel.serviceAvailable = true
                //                peripheral.discoverCharacteristics(characteristics, for: service)
            }else if service.uuid == CBUUID(string: LedServiceModelConstants.serviceUUID) {
                DDLogVerbose("* Service Discovery: Led Service found")
                let characteristics = serviceModel.characteristicUUIDs.cbUuids
                serviceModel.serviceAvailable = true
                peripheral.discoverCharacteristics(characteristics, for: service)
            } else if service.uuid == CBUUID(string: AlertServiceModelConstants.serviceUUID) {
                DDLogVerbose("* Service Discovery: Alert Service found")
                let characteristics = serviceModel.characteristicUUIDs.cbUuids
                serviceModel.serviceAvailable = true
                peripheral.discoverCharacteristics(characteristics, for: service)
            } else if service.uuid == CBUUID(string: CameraServiceModelConstants.serviceUUID) {
                DDLogVerbose("* Service Discovery: Camera Service found")
                let characteristics = serviceModel.characteristicUUIDs.cbUuids
                serviceModel.serviceAvailable = true
                peripheral.discoverCharacteristics(characteristics, for: service)
            }
        }
    }
    
    @objc public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            DDLogVerbose("Error occurred while discovering characteristic: \(error!.localizedDescription)")
            SLSensorManager.sharedInstance.centralManager?.cancelPeripheralConnection(peripheral)
            resetServices()
            return
        }
        
        guard let serviceModel = serviceModel(withUUID: service.uuid.uuidString), let characteristics = service.characteristics else {
            return
        }
        if service.uuid == CBUUID(string:MainServiceModelConstants.serviceUUID) {
            for characteristic in characteristics {
                if characteristic.uuid == CBUUID(string:MainServiceModelConstants.customCharUUID) {
                    DDLogVerbose("Reading value for Custom Char UUID")
                    if serviceModel.registerNotifyForCharacteristic(withUUID: characteristic.uuid.uuidString) {
                        peripheral.setNotifyValue(true, for: characteristic)
                        DDLogVerbose("*** Subscribed to Main Custom Char UUID *** ")
                    } else {
                        peripheral.setNotifyValue(false, for: characteristic)
                    }
                    // Notify ServiceModel the characteristic did become available.
                    serviceModel.characteristicAvailable(withUUID: characteristic.uuid.uuidString)
                } else if characteristic.uuid == CBUUID(string:MainServiceModelConstants.secondCustomCharUUID) {
                    DDLogVerbose("Reading value for secondCustomCharUUID characteristics")
                    // Check with correct ServiceModel if it should register for value changes.
                    if serviceModel.registerNotifyForCharacteristic(withUUID: characteristic.uuid.uuidString) {
                        peripheral.setNotifyValue(true, for: characteristic)
                        DDLogVerbose("*** Subscribed to Second Custom Char UUID *** ")
                    } else {
                        peripheral.setNotifyValue(false, for: characteristic)
                    }
                    // Notify ServiceModel the characteristic did become available.
                    serviceModel.characteristicAvailable(withUUID: characteristic.uuid.uuidString)
                } else if characteristic.uuid == CBUUID(string:MainServiceModelConstants.debugLogCharUUID) {
                    DDLogVerbose("Reading value for debug log characteristics")
                    // Check with correct ServiceModel if it should register for value changes.
                    if serviceModel.registerNotifyForCharacteristic(withUUID: characteristic.uuid.uuidString) {
                        peripheral.setNotifyValue(true, for: characteristic)
                    } else {
                        peripheral.setNotifyValue(false, for: characteristic)
                    }
                    
                    // Notify ServiceModel the characteristic did become available.
                    serviceModel.characteristicAvailable(withUUID: characteristic.uuid.uuidString)
                }
            }
        } else if service.uuid == CBUUID(string:DeviceInfoServiceModelConstants.serviceUUID) {
            for characteristic in characteristics {
                
                if characteristic.uuid == CBUUID(string:DeviceInfoServiceModelConstants.FirmwareRevisionUUID) {
                    DDLogVerbose("Reading value for Device FirmwareRevision")
                    if serviceModel.registerNotifyForCharacteristic(withUUID: characteristic.uuid.uuidString) {
                        peripheral.setNotifyValue(true, for: characteristic)
                        DDLogVerbose("*** Subscribed to Device Info FirmwareRevisionUUID *** ")
                    } else {
                        peripheral.setNotifyValue(false, for: characteristic)
                    }
                    // Notify ServiceModel the characteristic did become available.
                    serviceModel.characteristicAvailable(withUUID: characteristic.uuid.uuidString)
                } else if characteristic.uuid == CBUUID(string:DeviceInfoServiceModelConstants.HardwareRevisionUUID) {
                    DDLogVerbose("Reading value for HardwareRevisionUUID characterstic")
                    // Check with correct ServiceModel if it should register for value changes.
                    if serviceModel.registerNotifyForCharacteristic(withUUID: characteristic.uuid.uuidString) {
                        peripheral.setNotifyValue(true, for: characteristic)
                    } else {
                        peripheral.setNotifyValue(false, for: characteristic)
                    }
                    
                    // Notify ServiceModel the characteristic did become available.
                    serviceModel.characteristicAvailable(withUUID: characteristic.uuid.uuidString)
                } else if characteristic.uuid == CBUUID(string:DeviceInfoServiceModelConstants.ModelNumberUUID) {
                    DDLogVerbose("Reading value for ModelNumberUUID characterstic")
                    // Check with correct ServiceModel if it should register for value changes.
                    if serviceModel.registerNotifyForCharacteristic(withUUID: characteristic.uuid.uuidString) {
                        peripheral.setNotifyValue(true, for: characteristic)
                    } else {
                        peripheral.setNotifyValue(false, for: characteristic)
                    }
                    // Notify ServiceModel the characteristic did become available.
                    serviceModel.characteristicAvailable(withUUID: characteristic.uuid.uuidString)
                } else if characteristic.uuid == CBUUID(string:DeviceInfoServiceModelConstants.PairCodeUUID) {
                    DDLogVerbose("Reading value for PairCodeUUID characterstic")
                    // Check with correct ServiceModel if it should register for value changes.
                    if serviceModel.registerNotifyForCharacteristic(withUUID: characteristic.uuid.uuidString) {
                        peripheral.setNotifyValue(true, for: characteristic)
                    } else {
                        peripheral.setNotifyValue(false, for: characteristic)
                    }
                    // Notify ServiceModel the characteristic did become available.
                    serviceModel.characteristicAvailable(withUUID: characteristic.uuid.uuidString)
                }
            }
            
        } else if service.uuid == CBUUID(string:BatteryServiceModelConstants.serviceUUID) {
            for characteristic in characteristics {
                
                if characteristic.uuid == CBUUID(string:BatteryServiceModelConstants.batteryLevelUUID) {
                    DDLogVerbose("Reading value for Battery level characterstics")
                    //peripheral.readValue(for: characteristic)
                    // Check with correct ServiceModel if it should register for value changes.
                    if serviceModel.registerNotifyForCharacteristic(withUUID: characteristic.uuid.uuidString) {
                        peripheral.setNotifyValue(true, for: characteristic)
                        DDLogVerbose("*** Subscribed to Battery Level *** ")
                    } else {
                        peripheral.setNotifyValue(false, for: characteristic)
                    }
                    // Notify ServiceModel the characteristic did become available.
                    serviceModel.characteristicAvailable(withUUID: characteristic.uuid.uuidString)
                }
            }
            
            //        } else if service.uuid == CBUUID(string:RingServiceModelConstants.serviceUUID) {
            //            for characteristic in characteristics {
            //
            //                if characteristic.uuid == CBUUID(string:RingServiceModelConstants.sensor2MobileRingUUID) {
            //                    DDLogVerbose("Reading value for Sensor2Mobile Ring characterstic")
            //                    // Check with correct ServiceModel if it should register for value changes.
            //                    if serviceModel.registerNotifyForCharacteristic(withUUID: characteristic.uuid.uuidString) {
            //                        peripheral.setNotifyValue(true, for: characteristic)
            //                        DDLogVerbose("*** Subscribed to Sensor2Mobile Ring *** ")
            //                    } else {
            //                        peripheral.setNotifyValue(false, for: characteristic)
            //                    }
            //
            //                    // Notify ServiceModel the characteristic did become available.
            //                    serviceModel.characteristicAvailable(withUUID: characteristic.uuid.uuidString)
            //
            //                } else if characteristic.uuid == CBUUID(string:RingServiceModelConstants.mobile2SensorRingUUID) {
            //                    DDLogVerbose("Reading value for Mobile2Sensor Ring characterstic")
            //                    // Check with correct ServiceModel if it should register for value changes.
            //                    if serviceModel.registerNotifyForCharacteristic(withUUID: characteristic.uuid.uuidString) {
            //                        peripheral.setNotifyValue(true, for: characteristic)
            //                    } else {
            //                        peripheral.setNotifyValue(false, for: characteristic)
            //                    }
            //
            //                    // Notify ServiceModel the characteristic did become available.
            //                    serviceModel.characteristicAvailable(withUUID: characteristic.uuid.uuidString)
            //                }
            //            }
        } else if service.uuid == CBUUID(string:LedServiceModelConstants.serviceUUID) {
            for characteristic in characteristics {
                if characteristic.uuid == CBUUID(string:LedServiceModelConstants.ledOnOffLevelUUID) {
                    DDLogVerbose("Reading value for ledOnOffLevel characterstic")
                    if serviceModel.registerNotifyForCharacteristic(withUUID: characteristic.uuid.uuidString) {
                        peripheral.setNotifyValue(true, for: characteristic)
                    } else {
                        peripheral.setNotifyValue(false, for: characteristic)
                    }
                    
                    // Notify ServiceModel the characteristic did become available.
                    serviceModel.characteristicAvailable(withUUID: characteristic.uuid.uuidString)
                }
            }
        } else if service.uuid == CBUUID(string:AlertServiceModelConstants.serviceUUID)  {
            for characteristic in characteristics {
                if characteristic.uuid == CBUUID(string:AlertServiceModelConstants.alertLevelUUID) {
                    DDLogVerbose("Reading value for alertLevel characterstic")
                    if serviceModel.registerNotifyForCharacteristic(withUUID: characteristic.uuid.uuidString) {
                        peripheral.setNotifyValue(true, for: characteristic)
                        DDLogVerbose("*** Subscribed to alertLevel characterstic *** ")
                    } else {
                        peripheral.setNotifyValue(false, for: characteristic)
                    }
                    
                    // Notify ServiceModel the characteristic did become available.
                    serviceModel.characteristicAvailable(withUUID: characteristic.uuid.uuidString)
                }
            }
        } else if service.uuid == CBUUID(string: CameraServiceModelConstants.serviceUUID) {
            for characteristic in characteristics {
                if characteristic.uuid == CBUUID(string:CameraServiceModelConstants.cameraOnOffUUID) {
                    DDLogVerbose("Reading value for Camera Mode characterstic")
                    if serviceModel.registerNotifyForCharacteristic(withUUID: characteristic.uuid.uuidString) {
                        peripheral.setNotifyValue(true, for: characteristic)
                        DDLogVerbose("*** Subscribed to Camera Mode characterstic *** ")
                    } else {
                        peripheral.setNotifyValue(false, for: characteristic)
                    }
                    
                    // Notify ServiceModel the characteristic did become available.
                    serviceModel.characteristicAvailable(withUUID: characteristic.uuid.uuidString)
                    
                } else if characteristic.uuid == CBUUID(string:CameraServiceModelConstants.selfieClickUUID) {
                    DDLogVerbose("Reading value for Selie Click characterstic")
                    if serviceModel.registerNotifyForCharacteristic(withUUID: characteristic.uuid.uuidString) {
                        peripheral.setNotifyValue(true, for: characteristic)
                        DDLogVerbose("*** Subscribed to Selfie Click characterstic *** ")
                    } else {
                        peripheral.setNotifyValue(false, for: characteristic)
                    }
                    
                    // Notify ServiceModel the characteristic did become available.
                    serviceModel.characteristicAvailable(withUUID: characteristic.uuid.uuidString)
                }
            }
        }
    }
    
    @objc public func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) { }
    
    @objc public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        print("did didUpdateValueFor \(characteristic.value)")
        guard error == nil else {
            DDLogVerbose("Updating characteristic failed \(String(describing: error?.localizedDescription))")
            return
        }
        guard let serviceModel = serviceModel(withUUID: characteristic.service.uuid.uuidString) else {
            DDLogVerbose("Error serviceModel is nil in didUpdateValueFor")
            return
        }
        if characteristic.uuid == CBUUID(string:MainServiceModelConstants.customCharUUID) {
            
            DDLogVerbose("Main Custom characteristic value updated..")
            
            // Update the value of the changed characteristic.
            serviceModel.didRead(characteristic.value, withUUID: characteristic.uuid.uuidString)
        } else if characteristic.uuid == CBUUID(string:MainServiceModelConstants.secondCustomCharUUID) {
            DDLogVerbose("Second Custom characteristic value updated..")
            
            // Update the value of the changed characteristic.
            serviceModel.didRead(characteristic.value, withUUID: characteristic.uuid.uuidString)
        } else if characteristic.uuid == CBUUID(string:BatteryServiceModelConstants.batteryLevelUUID) {
            
            // Update the value of the changed characteristic.
            serviceModel.didRead(characteristic.value, withUUID: characteristic.uuid.uuidString)
            
        } else if characteristic.uuid == CBUUID(string:LedServiceModelConstants.ledOnOffLevelUUID) {
            
            DDLogVerbose("LED ON/OFF characteristic value updated")
            // Update the value of the changed characteristic.
            serviceModel.didRead(characteristic.value, withUUID: characteristic.uuid.uuidString)
            
        } else if characteristic.uuid == CBUUID(string:DeviceInfoServiceModelConstants.PairCodeUUID) {
            DDLogVerbose("Pairing Code updated")
            // Update the value of the changed characteristic.
            serviceModel.didRead(characteristic.value, withUUID: characteristic.uuid.uuidString)
            
        } else if characteristic.uuid == CBUUID(string:DeviceInfoServiceModelConstants.FirmwareRevisionUUID) {
            DDLogVerbose("FirmwareRevision Value Updated \(peripheral.name!)")
            // Update the value of the changed characteristic.
            serviceModel.didRead(characteristic.value, withUUID: characteristic.uuid.uuidString)
            
        } else if characteristic.uuid == CBUUID(string:DeviceInfoServiceModelConstants.HardwareRevisionUUID) {
            DDLogVerbose("HardwareRevision Value Updated \(peripheral.name!)")
            // Update the value of the changed characteristic.
            serviceModel.didRead(characteristic.value, withUUID: characteristic.uuid.uuidString)
            
            
        } else if characteristic.uuid == CBUUID(string:DeviceInfoServiceModelConstants.ModelNumberUUID) {
            DDLogVerbose("ModelNumberUUID Value Updated \(peripheral.name!)")
            // Update the value of the changed characteristic.
            serviceModel.didRead(characteristic.value, withUUID: characteristic.uuid.uuidString)
        } else if characteristic.uuid == CBUUID(string:AlertServiceModelConstants.alertLevelUUID) {
            DDLogVerbose("Alert Mode Value Updated")
            // Update the value of the changed characteristic.
            serviceModel.didRead(characteristic.value, withUUID: characteristic.uuid.uuidString)
            
        } else if characteristic.uuid == CBUUID(string:CameraServiceModelConstants.cameraOnOffUUID) {
            DDLogVerbose("Camera Mode Value Updated")
            // Update the value of the changed characteristic.
            serviceModel.didRead(characteristic.value, withUUID: characteristic.uuid.uuidString)
            
        }
        else if characteristic.uuid == CBUUID(string:"A103") {
            DDLogVerbose("Camera Mode Value Updated")
            // Update the value of the changed characteristic.
            NotificationCenter.default.post(
                name: Notification.Name(rawValue: "UpdateDetailsConnectionStatus"), object: nil, userInfo: nil)
            NotificationCenter.default.post(
                name: Notification.Name(rawValue: ManagerConstants.refreshStatusKey), object: nil, userInfo: nil)
            
            
        }
        
    }
    
    @objc public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            DDLogVerbose("Writing value to descriptor \(characteristic.uuid) has failed -> \(String(describing: error?.localizedDescription))")
            return
        }
        if characteristic.uuid == CBUUID(string:MainServiceModelConstants.customCharUUID) {
            DDLogVerbose("Did Write Custom Char Value for \(peripheral.name!)")
        } else if characteristic.uuid == CBUUID(string:DeviceInfoServiceModelConstants.PairCodeUUID) {
            DDLogVerbose("Log:- Did Write Pairing Code for \(peripheral.name!)")
        } else if characteristic.uuid == CBUUID(string:AlertServiceModelConstants.alertLevelUUID) {
            DDLogVerbose("Did Write Alert Mode Value \(peripheral.name!)")
        } else if characteristic.uuid == CBUUID(string:CameraServiceModelConstants.cameraOnOffUUID) {
            DDLogVerbose("Did Write Camera Mode Value \(peripheral.name!)")
            //        } else if characteristic.uuid == CBUUID(string:RingServiceModelConstants.sensor2MobileRingUUID) {
            //            DDLogVerbose("Did Write Sensor2MobileRing Value \(peripheral.name!)")
        } else if characteristic.uuid == CBUUID(string:DeviceInfoServiceModelConstants.HardwareRevisionUUID) {
            DDLogVerbose("Log:- Did Write HardwareRevisionUUID Value \(peripheral.name!)")
        } else if characteristic.uuid == CBUUID(string:DeviceInfoServiceModelConstants.ModelNumberUUID) {
            DDLogVerbose("Log:- Did Write ModelNumberUUID Value \(peripheral.name!)")
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        if RSSI.intValue < 0 {
            guard let peripheralUUID = UserDefaults.standard.string(forKey: peripheral.identifier.uuidString) else {
                return
            }
            SLSensorManager.sharedInstance.foundDevices.filter{ (String($0.trackerUUID.prefix(18)) == peripheralUUID)}.forEach { sensor in
                SLCloudConnector.sharedInstance.devicesList?.sensorArray?.filter{ ($0.UUID == peripheralUUID)}.forEach { sensor in
                    DDLogVerbose("RSSI-Observer =>\(String(describing: sensor.trackerName!)) => RSSI \(String(describing: RSSI.intValue))")
                }
                sensor.rssi = RSSI.intValue
                sensor.markSensorActivity()
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if error == nil{
            print("value for charectstics \(characteristic) suceed \(String(describing: characteristic.value))")
            guard error == nil else {
                return
            }
            notifyHandler?(characteristic)
        }
    }
}

extension Collection where Iterator.Element == String {
    var cbUuids:[CBUUID] {
        return self.map { CBUUID(string: $0) }
    }
}

//extension Array where Element:Device {
//    //    fileprivate func create(from peripheral: CBPeripheral) -> Device {
//    //        return self.filter { $0.peripheral.identifier == peripheral.identifier }.first //?? Device(withPeripheral: peripheral, aTrackerID: "", andRSSI: 32, andIsConnected: false)
//    //    }
//
//    fileprivate func has(peripheral: CBPeripheral) -> Bool {
//        return (self.filter { $0.peripheral.identifier == peripheral.identifier }).count > 0
//    }
//}

