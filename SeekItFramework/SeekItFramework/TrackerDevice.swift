//
//  TrackerDevice.swift
//  SeekLib
//
//  Created by Chamoli, Jitendra on 24/12/17.
//  Copyright © 2018 Wavenet Solutions. All rights reserved.
//
import CoreBluetooth
import CoreLocation
import Signals
import CocoaLumberjack

/**
 TrackerDevice wraps a CoreBluetooth Peripheral and manages the hierarchy of Services and Characteristics.
 */
open class TrackerDevice: NSObject {
    
    // Internal Constructor. SensorManager manages the instantiation and destruction of Sensor objects
    required public init(peripheral: CBPeripheral, trackerID: String, advertisements: [CBUUID] = []) {
        basePeripheral = peripheral
        trackerUUID = trackerID
        self.advertisements = advertisements
        basePeripheralState = CBPeripheralState.disconnected//"disconnected"
        
        serviceModelManager = SensorServiceModelManager(peripheral: peripheral)
        super.init()
        
        // Register for Available Sensor Services
        register(serviceModel: mainServiceModel)
        register(serviceModel: deviceServiceModel)
        register(serviceModel: batteryServiceModel)
        
        // Set Peripheral Delegate to ServiceModelManager
        basePeripheral.delegate = serviceModelManager
        basePeripheral.addObserver(self, forKeyPath: "state", options: [.new, .old], context: &myContext)
    }
    
    deinit {
        basePeripheral.removeObserver(self, forKeyPath: "state")
        basePeripheral.delegate = nil
        onStateChanged.cancelAllSubscriptions()
        rssiPingTimer?.invalidate()
        DDLogVerbose("Tracker \(String(describing: basePeripheral.name)) Deinit Called")
    }
    
    /// Backing CoreBluetooth Peripheral
    public private(set) var basePeripheral: CBPeripheral
    
    /// Base Peripheral State
    public var basePeripheralState : CBPeripheralState = CBPeripheralState.disconnected
    
    /// Pairing Code that is mandatory to write after device is connected
    public var pairingCode : String = ""
    public var deviceNickName : String = "Panasonic"
    public var buzzTime: String = "10" // In Seconds
    public var alertMode:NSNumber = AppConstants.HIGH_ALERT_MODE
    public var tempAlertMode:NSNumber = AppConstants.LOW_ALERT_MODE
    
    // Concurrent queue with barrier to improve and speedup code.
    private lazy var concurrentQueue:DispatchQueue = DispatchQueue(label: ManagerConstants.dispatchQueueLabel, attributes: .concurrent) //[])
    
    // Buzz Timer
    public var buzzTimer = Timer()
    //    var disconnectTimer: Timer?
    public var seconds = 15
    public var isTimerRunning = false
    
    var timeStamp:Date = Date()
    
    /// Advertised UUIDs
    public let advertisements: [CBUUID]
    
    /// Unique Sensor ID
    public let trackerUUID: String
    
    // SeekIt UUID is 18 Char Prefix
    public var seekitUUID: String {
        get {
            return String(self.trackerUUID.prefix(18))
        }
        set(newValue) {
        }
    }
    
    // The ServiceModelManager that will manage all registered `ServiceModels`
    public private(set) var serviceModelManager: SensorServiceModelManager
    
    /// Name Changed Signal
    public let onNameChanged = Signal<TrackerDevice>()
    
    /// State Changed Signal
    public let onStateChanged = Signal<TrackerDevice>()
    
    /// RSSI Changed Signal
    public let onRSSIChanged = Signal<(TrackerDevice, Int)>()
    
    /// RSSI Changed Signal
    public let onBatteryLevelChanged = Signal<(TrackerDevice, Int)>()
    
    // Service Models
    public let mainServiceModel    = MainServiceModel()
    public let deviceServiceModel  = DeviceInfoServiceModel()
    public let batteryServiceModel = BatteryServiceModel()
    
    /// Most recent RSSI value
    public internal(set) var rssi: Int = Int.min {
        didSet {
            evaluateRSSI(rssi: rssi)
            onRSSIChanged => (self, rssi)
        }
    }
    public var avgRssi: Double {
        get {
            if self.rssiValues.count > 0 {
                return Double(self.rssiValues.reduce(0,+))/Double(self.rssiValues.count)
            } else {
                return 0.0
            }
        }
    }
    
    /// Most recent Battery Level value
    public internal(set) var batteryLevel: Int = Int.min {
        didSet {
            onBatteryLevelChanged => (self, batteryLevel)
        }
    }
    
    /**
     Register a `ServiceModel` subclass.
     Register before connecting to the device.
     
     - parameter serviceModel: The ServiceModel subclass to register.
     */
    
    public func register(serviceModel: ServiceModel) {
        serviceModelManager.register(serviceModel: serviceModel)
    }
    
    /// Last time of Sensor Communication with the Sensor Manager (Time Interval since Reference Date)
    public fileprivate(set) var lastSensorActivity = Date.timeIntervalSinceReferenceDate
    
    
    /**
     Check if a Sensor advertised a specific UUID Service
     
     - parameter uuid: UUID string
     - returns: `true` if the sensor advertised the `uuid` service
     */
    open func advertisedService(_ uuid: String) -> Bool {
        let service = CBUUID(string: uuid)
        for advertisement in advertisements {
            if advertisement.isEqual(service) {
                return true
            }
        }
        return false
    }
    
    public func asBeaconRegion() -> CLBeaconRegion {
        let proximityString:String = "01122334-4556-6778-899A-ABBCCDDEEFF0"
        return CLBeaconRegion(proximityUUID: UUID(uuidString: proximityString)!,
                              major: 4660,
                              minor: 39031,
                              identifier: basePeripheral.name!)
    }
    
    //////////////////////////////////////////////////////////////////
    // Private / Internal Classes, Properties and Constants
    //////////////////////////////////////////////////////////////////
    
    //internal weak var serviceFactory: SensorManager.ServiceFactory?
    private var rssiPingTimer: Timer?
    private var rssiValues: [Int] = []
    private var is4dBmModeEnabled = false
    private var myContext = 0
    public let writeQueue = WriterQueue()
    
    /// :nodoc:
    override open func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &myContext {
            if keyPath == "state" {
                peripheralStateChanged()
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    fileprivate var rssiPingEnabled: Bool = false {
        didSet {
            if rssiPingEnabled {
                if rssiPingTimer == nil {
                    DispatchQueue.main.async {
                        if #available(iOS 10.0, *) {
                            self.rssiPingTimer = Timer.scheduledTimer(withTimeInterval: SLSensorManager.RSSIPingInterval, repeats: true, block: { _ in
                                self.rssiPingTimerHandler()
                            })
                        } else {
                            self.rssiPingTimer = Timer.scheduledTimer(timeInterval: SLSensorManager.RSSIPingInterval, target: self, selector: #selector(self.rssiPingTimerHandler), userInfo: nil, repeats: true)
                        }
                    }
                }
            } else {
                rssi = Int.min
                rssiPingTimer?.invalidate()
                rssiPingTimer = nil
            }
        }
    }
    
    public func runTimer() {
        seconds = Int(buzzTime)!
        buzzTimer.invalidate()
        buzzTimer = Timer.scheduledTimer(timeInterval: 1, target: self,   selector: (#selector(updateTimer)), userInfo: nil, repeats: true)
        isTimerRunning = true
    }
    
    @objc func updateTimer() {
        seconds -= 1
        print("test :- ", seconds)
        isTimerRunning = true
        if seconds == 0 {
            stopTimer()
        }
    }
    
    public func stopTimer(refreshRequired:Bool = true) {
        buzzTimer.invalidate()
        isTimerRunning = false
        seconds = Int(buzzTime)!
        DDLogVerbose("JCTimer:- Buzz Timer Stopped for \(basePeripheral.name!)")
        DDLogVerbose("JCTimer:- Notify UI to update")
        SLCloudConnector.sharedInstance.devicesList?.sensorArray?.filter({ $0.UUID == String(self.trackerUUID.prefix(18)) }).forEach { foundSensor in
            foundSensor.isBuzzing = false
        }
        if (refreshRequired)
        {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name(rawValue: ManagerConstants.refreshStatusKey), object: nil, userInfo: nil)
                
                
                NotificationCenter.default.post(name: Notification.Name(rawValue:"UpdateDetailsConnectionStatus"), object: nil)
                
                
            }
        }
    }
    
    @objc func disconnect() {
        DispatchQueue.main.async {
            self.basePeripheralState = .disconnected
            self.rssiPingEnabled = false
            self.serviceModelManager.resetServices()
            SLSensorManager.logSensorMessage?("Sensor: \(String(describing: self.basePeripheral.name)) peripheralStateChanged: \(self.basePeripheral.state.rawValue)")
            self.onStateChanged => self
        }
    }
}

// Private Funtions

extension TrackerDevice {
    
    public func subsrcibeState(_ foundDevices: [TrackerDevice]) {
        
        if let sensorArray = SLCloudConnector.sharedInstance.devicesList?.sensorArray {
            sensorArray.forEach({ sensorDevice in
                for foundDevice in foundDevices {
                    if String(foundDevice.trackerUUID.prefix(18)) == sensorDevice.UUID {
                        
                        foundDevice.onStateChanged.cancelAllSubscriptions()
                        foundDevice.onStateChanged.subscribe(with: self) { sensor in
                            let state = (sensor.basePeripheral.state, sensor.basePeripheralState)
                            
                            switch state {
                            case (.connected, _):
                                if sensorDevice.lostMode == 2 {
                                    SLSensorManager.sharedInstance.updateTrackerInfo(sensor: sensorDevice)
                                }
                                if let userID = UserDefaults.standard.string(forKey: AppConstants.userIDKey), sensorDevice.connectionStatus != "connected" {
                                    DDLogVerbose("Writing Tracker Auto Connect Event for Device UUID \(sensorDevice.UUID!) userID \(userID)")
                                    let newLog = TrackerLog()
                                    newLog.eventId = UUID().uuidString
                                    newLog.eventDate = Date()
                                    newLog.trackerUUID = sensorDevice.UUID!
                                    newLog.eventType = EventType.autoConnect.rawValue
                                    DispatchQueue.main.async {
                                        SLRealmManager.sharedInstance.writeLog(logInfo: newLog)
                                    }
                                }
                                foundDevice.basePeripheralState = .connected
                                sensorDevice.connectionStatus = "connected"
                                sensorDevice.uploadStatus = nil
                                sensorDevice.progressLabel = nil
                            case (.connecting, _):
                                if sensorDevice.connectionStatus != "lost" {
                                    sensorDevice.connectionStatus = "connecting"
                                    foundDevice.basePeripheralState = .connecting
                                    SLSensorManager.sharedInstance.locationManager.getQuickLocationUpdate()
                                    SLSensorManager.sharedInstance.startLocationUpdator()
                                }
                            case (_ ,.connecting):
                                if sensorDevice.connectionStatus != "lost" {
                                    sensorDevice.connectionStatus = "connecting"
                                    foundDevice.basePeripheralState = .connecting
                                    SLSensorManager.sharedInstance.locationManager.getQuickLocationUpdate()
                                    SLSensorManager.sharedInstance.startLocationUpdator()
                                }
                            case (.disconnected,_):
                                if sensorDevice.connectionStatus != "lost" {
                                    sensorDevice.connectionStatus = "disconnected"
                                    foundDevice.basePeripheralState = .disconnected
                                    DDLogVerbose("\(sensorDevice.trackerName!) disconnected")
                                }
                            case (.disconnecting, _):
                                sensorDevice.connectionStatus = "disconnecting"
                                foundDevice.basePeripheralState = .disconnecting
                            default:
                                break
                            }
                            
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(
                                    name: Notification.Name(rawValue: ManagerConstants.refreshStatusKey), object: nil, userInfo: nil)
                                NotificationCenter.default.post(
                                    name: Notification.Name(rawValue: "TrackerMapUpdate"), object: nil, userInfo: nil)
                                NotificationCenter.default.post(
                                    name: Notification.Name(rawValue: "UpdateDetailsConnectionStatus"), object: nil, userInfo: nil)
                            }
                        }
                    }
                }
                
            })
        }
    }
    
    
    public func updateSensorInfo() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if self.basePeripheral.state == .connected {
                
                //self.writePairingCode()
                self.deviceServiceModel.readValue(withUUID: DeviceInfoServiceModelConstants.FirmwareRevisionUUID)
                usleep(2000)
                self.writeQueue.addOperation(operation: Operation(bleTracker: self, type: OperationType.PairingCode, complitionHandler: {
                    
                }))
                
                // ** TO CHECK SLEEP MODE AND WIFI MODE SETTINGS ** //
                let sleepModeActive = SLSensorManager.sharedInstance.isSleepModeActivated()
                let wifiModeActive = SLSensorManager.sharedInstance.isWifiModeActivated()
                let pickPocketModeActive = SLSensorManager.sharedInstance.isPickPocketModeActivated()
                let dndModeActive = SLSensorManager.sharedInstance.isDNDModeActivated()
                
                if pickPocketModeActive {
                    //                    self.turnOnAlertMode()
                    self.writeQueue.addOperation(operation: Operation(bleTracker: self, type: OperationType.HightAlertMode, complitionHandler: {
                    }))
                } else if sleepModeActive || wifiModeActive || dndModeActive {
                    //                    self.turnOffAlertMode()
                    self.writeQueue.addOperation(operation: Operation(bleTracker: self, type: OperationType.LowAlertMode, complitionHandler: {
                    }))
                }else if self.alertMode == AppConstants.HIGH_ALERT_MODE {
                    //                    self.turnOnAlertMode()
                    self.writeQueue.addOperation(operation: Operation(bleTracker: self, type: OperationType.HightAlertMode, complitionHandler: {
                    }))
                } else {
                    //                    self.turnOffAlertMode()
                    self.writeQueue.addOperation(operation: Operation(bleTracker: self, type: OperationType.LowAlertMode, complitionHandler: {
                    }))
                }
                self.writeQueue.addOperation(operation: Operation(bleTracker: self, type: OperationType.PickPocketMode, complitionHandler: {
                    
                }))
                self.writeQueue.addOperation(operation: Operation(bleTracker: self, type: OperationType.SetBuzzTime, complitionHandler: {
                }))
                
                self.writeQueue.addOperation(operation: Operation(bleTracker: self, type: OperationType.SetBlinkTime, complitionHandler: {
                }))
                
                self.writeQueue.addOperation(operation: Operation(bleTracker: self, type: OperationType.Rename, complitionHandler: {
                    
                }))
                
                self.writeQueue.addOperation(operation: Operation(bleTracker: self, type: OperationType.BetterAdaptiveMode, complitionHandler: {
                    usleep(2000)
                    self.enableSpecialConnectionParameters()
                    usleep(2000)
                    self.readFirmwareValue()
                    
                }))
                if !self.writeQueue.isInProcess{
                    self.writeQueue.invokeQueue()
                }
            } else {
                self.updateSensorInfo()
            }
        }
    }
    
    func peripheralStateChanged() {
        let state = (basePeripheral.state, basePeripheralState)
        
        switch state {
        case (.connected, _):
            rssiPingEnabled = true
            self.is4dBmModeEnabled = false
            self.rssiValues.removeAll()
            basePeripheralState = .connected
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                guard let strongSelf = self else { return }
                if SLSensorManager.sharedInstance.fdsDevices.count > 0 {
                    DDLogVerbose("FDSLog:- FDS Recovery Mode ")
                    SLSensorManager.sharedInstance.fdsDevices.forEach({ sensor in
                        var fdsDict: [String: Any] = [:]
                        fdsDict["UUID"] = String(sensor.trackerUUID.prefix(18))
                        NotificationCenter.default.post(
                            name: Notification.Name(rawValue: ManagerConstants.triggerActionForFDSErrorKey), object: nil, userInfo: fdsDict)
                    })
                } else {
                    DDLogVerbose("FDSLog:- Normal Mode ")
                    DDLogVerbose("FDSLog:- Pair Code \(String(describing: strongSelf.pairingCode))")
                }
            }
            
        case (.connecting, _):
            basePeripheralState = .connecting
            
            break
        case (.disconnecting,_):
            basePeripheralState = .disconnecting
            break
        case (.disconnected, _):
            basePeripheralState = SLSensorManager.sharedInstance.bluetoothEnabled ? .connecting : .disconnected
            
            fallthrough
        default:
            rssiPingEnabled = false
            serviceModelManager.resetServices()
        }
        
        SLSensorManager.logSensorMessage?("Sensor: \(String(describing: basePeripheral.name)) peripheralStateChanged: \(basePeripheral.state.rawValue)")
        onStateChanged => self
        
    }
    
    @objc func rssiPingTimerHandler() {
        if basePeripheral.state == .connected && !SLSensorManager.sharedInstance.updatingDFUDevice && basePeripheral.delegate != nil {
            basePeripheral.readRSSI()
        }
    }
    
    /**
     Evaluate previous 10 rssi of connected devices and if average rssi is less than equal to -80 then enable4dBm().
     
     - parameter rssi: current rssi of the device.
     */
    
    public func evaluateRSSI(rssi: Int) {
        if self.basePeripheral.state == .connected && rssi > -9999 {
            rssiValues.append(rssi)
            DDLogVerbose("\(self.deviceNickName) average RSSI \(avgRssi)")
            if rssiValues.count >= 10 {
                if avgRssi <= -80  && !is4dBmModeEnabled {
                    is4dBmModeEnabled = true
                    disableBetterAdaptiveMode { (char) in }
                    enable4dBm()
                }
                rssiValues.remove(at: 0)
            }
        }
    }
    
    internal func markSensorActivity() {
        lastSensorActivity = Date.timeIntervalSinceReferenceDate
    }
    
    internal func hexEncodedPassKey() -> [UInt8] {
        
        let datat = pairingCode.data(using: .utf8)!
        let hexString = datat.map{ (String(format:"%02x", $0)) }
        print(hexString)
        var newbyte:[UInt8] = [0xA7]
        hexString.forEach { byteString in
            switch byteString {
            case "30":
                newbyte.append(0x30)
                break
            case "31":
                newbyte.append(0x31)
                break
            case "32":
                newbyte.append(0x32)
                break
            case "33":
                newbyte.append(0x33)
                break
            case "34":
                newbyte.append(0x34)
                break
            case "35":
                newbyte.append(0x35)
                break
            case "36":
                newbyte.append(0x36)
                break
            case "37":
                newbyte.append(0x37)
                break
            case "38":
                newbyte.append(0x38)
                break
            case "39":
                newbyte.append(0x39)
                break
            default:
                break
            }
        }
        print(newbyte)
        return newbyte
    }
    
    // MARK:- Led Service Actions
    
    public func turnOnLED() {
        let bytes : [UInt8] = [ 0xA1, 0x02 ]
        print(bytes)
        let data = Data(bytes:bytes)
        mainServiceModel.controlPoint = data
        self.mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID)
    }
    
    public func startBlink(complitionHandler : @escaping (_ charecterstic:CBCharacteristic) -> Void){
        let bytes : [UInt8] = [ 0xA1, 0x02 ]
        print(bytes)
        let data = Data(bytes:bytes)
        mainServiceModel.controlPoint = data
        mainServiceModel.setNotify(enabled: true, forUUID: MainServiceModelConstants.customCharUUID)
        mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID, complition: complitionHandler)
    }
    
    public func turnOffLED() {
        let bytes : [UInt8] = [ 0xA1, 0x04 ]
        print(bytes)
        let data = Data(bytes:bytes)
        mainServiceModel.controlPoint = data
        concurrentQueue.async(flags: .barrier) {
            self.mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID)
        }
    }
    
    public func stopBlink(complitionHandler : @escaping (_ charecterstic:CBCharacteristic) -> Void){
        let bytes : [UInt8] = [ 0xA1, 0x04 ]
        // print(bytes)
        let data = Data(bytes:bytes)
        mainServiceModel.controlPoint = data
        mainServiceModel.setNotify(enabled: true, forUUID: MainServiceModelConstants.customCharUUID)
        mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID, complition: complitionHandler)
    }
    
    
    public func setDeviceName(deviceName: String) {
        
        var bytes: [UInt8] = [UInt8]()
        
        bytes = [ 0xA8 ]
        
        let nameArray: [UInt8] = Array(deviceName.utf8)
        bytes.append(contentsOf: nameArray)
        print(bytes)
        let data = Data(bytes:bytes)
        mainServiceModel.controlPoint = data
        mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID)
    }
    
    public func setDeviceName(complitionHandler : @escaping (_ charecterstic:CBCharacteristic) -> Void){
        
        var bytes: [UInt8] = [UInt8]()
        
        bytes = [ 0xA8 ]
        
        let nameArray: [UInt8] = Array(self.deviceNickName.utf8)
        bytes.append(contentsOf: nameArray)
        print(bytes)
        let data = Data(bytes:bytes)
        mainServiceModel.controlPoint = data
        mainServiceModel.setNotify(enabled: true, forUUID: MainServiceModelConstants.customCharUUID)
        mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID, complition: complitionHandler)
    }
    
    public func enable4dBm() {
        
        var bytes: [UInt8] = [UInt8]()
        // Firmware will increase power to lower down disconnection rate.
        bytes = [ 0xC2, 0x04 ] // 04
        
        let data = Data(bytes:bytes)
        DDLogVerbose("Writing 4dBm for \(String(describing: basePeripheral.name))")
        mainServiceModel.controlPoint = data
        mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID)
    }
    
    public func enablePickPocketMode(complitionHandler : @escaping (_ charecterstic:CBCharacteristic) -> Void){
        
        var bytes: [UInt8] = [UInt8]()
        // Reducing the buffer time to 1
        bytes = [ 0xE1, 0x01 ] // 04
        
        let data = Data(bytes:bytes)
        DDLogVerbose("Writing pickpocket Mode enable for \(String(describing: basePeripheral.name))")
        mainServiceModel.controlPoint = data
        mainServiceModel.setNotify(enabled: true, forUUID: MainServiceModelConstants.customCharUUID)
        mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID, complition: complitionHandler)
    }
    
    public func disablePickPocketMode(complitionHandler : @escaping (_ charecterstic:CBCharacteristic) -> Void){
        
        var bytes: [UInt8] = [UInt8]()
        // Increasing the buffer time to 90(hex = 5A) sec
        bytes = [ 0xE1, 0x5A ]
        
        let data = Data(bytes:bytes)
        DDLogVerbose("Writing pickpocket Mode disable for \(String(describing: basePeripheral.name))")
        mainServiceModel.controlPoint = data
        mainServiceModel.setNotify(enabled: true, forUUID: MainServiceModelConstants.customCharUUID)
        mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID, complition: complitionHandler)
    }
    
    public func enableBetterAdaptiveMode(complitionHandler : @escaping (_ charecterstic:CBCharacteristic) -> Void){
        
        var bytes: [UInt8] = [UInt8]()
        // Better Adaptive Mode - Enable Bits
        // Firmware will increase power to lower down disconnection rate.
        bytes = [ 0xCE, 0x04 ] // 04
        
        let data = Data(bytes:bytes)
        DDLogVerbose("Writing Better adaptive enable Mode for \(String(describing: basePeripheral.name))")
        mainServiceModel.controlPoint = data
        mainServiceModel.setNotify(enabled: true, forUUID: MainServiceModelConstants.customCharUUID)
        mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID, complition: complitionHandler)
    }
    
    public func disableBetterAdaptiveMode(complitionHandler : @escaping (_ charecterstic:CBCharacteristic) -> Void){
        
        var bytes: [UInt8] = [UInt8]()
        // Better Adaptive Mode - Enable Bits
        // Much chances of disconnect when the bit is 00
        bytes = [ 0xCE, 0x00 ]
        
        let data = Data(bytes:bytes)
        DDLogVerbose("Writing Better Adaptive Mode disable for \(String(describing: basePeripheral.name))")
        mainServiceModel.controlPoint = data
        mainServiceModel.setNotify(enabled: true, forUUID: MainServiceModelConstants.customCharUUID)
        mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID, complition: complitionHandler)
    }
    
    public func setPickPocketModeValues(complitionHandler : @escaping (_ charecterstic:CBCharacteristic) -> Void){
        
        let pickPocketStatus = SLSensorManager.sharedInstance.isPickPocketModeActivated()
        
        if pickPocketStatus == true{
            enablePickPocketMode { (char) in
                complitionHandler(char)
            }
        } else {
            disablePickPocketMode { (char) in
                complitionHandler(char)
            }
        }
    }
    
    public func setBetterAdaptiveModeValues(complitionHandler : @escaping (_ charecterstic:CBCharacteristic) -> Void){
        
        if let deviceArray = SLCloudConnector.sharedInstance.devicesList?.sensorArray, let _ = deviceArray.filter( {$0.UUID == String(trackerUUID.prefix(18))}).first { //, let pickPocketStatus = mainDevice.pickPocketMode {
            
            // ** TO CHECK SLEEP MODE AND WIFI MODE SETTINGS ** //
            let sleepModeActive = SLSensorManager.sharedInstance.isSleepModeActivated()
            let pickPocketStatus = SLSensorManager.sharedInstance.isPickPocketModeActivated()
            //let wifiModeActive = SLSensorManager.sharedInstance.isWifiModeActivated()
            
            if sleepModeActive == true || pickPocketStatus == true{
                // Disable Better Adaptive Mode when DND is active
                disableBetterAdaptiveMode { (char) in
                    complitionHandler(char)
                }
            } else {
                // Enable Better Adaptive Mode when DND is disabled
                enableBetterAdaptiveMode { (char) in
                    complitionHandler(char)
                }
            }
        }
    }
    
    // MARK:- Device Service Actions
    public func writePairingCode() {
        // Write (Data([0x1]))
        //let bytes : [UInt8] = [ 0xA7, 0x32, 0x31, 0x39, 0x30, 0x37, 0x36 ]
        
        DDLogVerbose("Writing passkey Code \(pairingCode) for \(String(describing: basePeripheral.name))")
        let bytes : [UInt8] = hexEncodedPassKey() //[ 0xA7, 0x32, 0x31, 0x39, 0x30, 0x37, 0x36 ]
        print(bytes)
        let data = Data(bytes:bytes)
        mainServiceModel.controlPoint = data
        mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID)
    }
    
    public func writingPairingCode(complitionHandler : @escaping (_ charecterstic:CBCharacteristic) -> Void){
        // Write (Data([0x1]))
        //let bytes : [UInt8] = [ 0xA7, 0x32, 0x31, 0x39, 0x30, 0x37, 0x36 ]
        
        DDLogVerbose("Writing passkey Code \(pairingCode) for \(String(describing: basePeripheral.name))")
        let bytes : [UInt8] = hexEncodedPassKey() //[ 0xA7, 0x32, 0x31, 0x39, 0x30, 0x37, 0x36 ]
        print(bytes)
        let data = Data(bytes:bytes)
        mainServiceModel.controlPoint = data
        mainServiceModel.setNotify(enabled: true, forUUID: MainServiceModelConstants.customCharUUID)
        mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID, complition: complitionHandler)
    }
    
    // MARK:- Turn on Adaptive Mode
    public func turnOnAdaptiveMode() {
        DDLogVerbose("Turn ON Adaptive Mode for \(String(describing: basePeripheral.name))")
        let bytes : [UInt8] = [ 0xCD, 0x01 ]
        print(bytes)
        let data = Data(bytes:bytes)
        mainServiceModel.controlPoint = data
        mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID)
    }
    
    public func enableSpecialConnectionParameters() {
        
        DDLogVerbose("Turn ON Special Test Mode for \(String(describing: basePeripheral.name))")
        let bytes : [UInt8] = [ 0xC3, 0x33, 0x3C, 0x00, 0x06 ]
        print(bytes)
        let data = Data(bytes:bytes)
        mainServiceModel.controlPoint = data
        mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID)
        
    }
    
    // MARK:- Turn on Adaptive Mode
    public func turnOffAdaptiveMode() {
        DDLogVerbose("Turn ON Adaptive Mode for \(String(describing: basePeripheral.name))")
        let bytes : [UInt8] = [ 0xCD, 0x02 ]
        print(bytes)
        let data = Data(bytes:bytes)
        mainServiceModel.controlPoint = data
        mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID)
    }
    
    public func subcribeToTrackerRSSI() {
        //0xAD01
        DDLogVerbose("Turn On Subscription to Tracker RSSI \(String(describing: basePeripheral.name))")
        let bytes : [UInt8] = [ 0xAD, 0x01 ]
        print(bytes)
        let data = Data(bytes:bytes)
        mainServiceModel.controlPoint = data
        mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID)
    }
    
    public func setBuzzzingTimeDuration() {
        DDLogVerbose("Setting Buzz Duration For \(String(describing: basePeripheral.name))")
        let hexString = String(format:"%02X", UInt8(bitPattern:Int8(buzzTime)!))
        let byteArray = "\(hexString)".hexa2Bytes
        DDLogVerbose("Buzzing Time in Hex:- \(hexString)")
        DDLogVerbose("Setting Buzzing Time for \(String(describing: basePeripheral.name))")
        var bytes : [UInt8] = [ 0xAB ]
        bytes.append(contentsOf: byteArray)
        print(bytes)
        let data = Data(bytes:bytes)
        mainServiceModel.controlPoint = data
        mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID)
    }
    
    public func setBuzzTime(complitionHandler : @escaping (_ charecterstic:CBCharacteristic) -> Void){
        DDLogVerbose("Setting Buzz Duration For \(String(describing: basePeripheral.name))")
        let hexString = String(format:"%02X", UInt8(bitPattern:Int8(buzzTime)!))
        let byteArray = "\(hexString)".hexa2Bytes
        DDLogVerbose("Buzzing Time in Hex:- \(hexString)")
        DDLogVerbose("Setting Buzzing Time for \(String(describing: basePeripheral.name))")
        var bytes : [UInt8] = [ 0xAB ]
        bytes.append(contentsOf: byteArray)
        print(bytes)
        let data = Data(bytes:bytes)
        mainServiceModel.controlPoint = data
        mainServiceModel.setNotify(enabled: true, forUUID: MainServiceModelConstants.customCharUUID)
        mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID, complition: complitionHandler)
    }
    
    public func setLedBlinkTimeDuration() {
        DDLogVerbose("Setting Blink Duration For \(String(describing: basePeripheral.name))")
        let hexString = String(format:"%02X", UInt8(bitPattern:Int8(buzzTime)!))
        let byteArray = "\(hexString)".hexa2Bytes
        DDLogVerbose("Led Buzzing Time in Hex:- \(hexString)")
        DDLogVerbose("Setting Led Buzzing Time for \(String(describing: basePeripheral.name))")
        var bytes : [UInt8] = [ 0xAE ]
        bytes.append(contentsOf: byteArray)
        let data = Data(bytes:bytes)
        mainServiceModel.controlPoint = data
        mainServiceModel.setNotify(enabled: true, forUUID: MainServiceModelConstants.customCharUUID)
        mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID)
    }
    
    public func setLedBlinkTimeDuration(complitionHandler : @escaping (_ charecterstic:CBCharacteristic) -> Void){
        DDLogVerbose("Setting Blink Duration For \(String(describing: basePeripheral.name))")
        let hexString = String(format:"%02X", UInt8(bitPattern:Int8(buzzTime)!))
        let byteArray = "\(hexString)".hexa2Bytes
        DDLogVerbose("Led Buzzing Time in Hex:- \(hexString)")
        DDLogVerbose("Setting Led Buzzing Time for \(String(describing: basePeripheral.name))")
        var bytes : [UInt8] = [ 0xAE ]
        bytes.append(contentsOf: byteArray)
        print(bytes)
        let data = Data(bytes:bytes)
        mainServiceModel.controlPoint = data
        mainServiceModel.setNotify(enabled: true, forUUID: MainServiceModelConstants.customCharUUID)
        mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID, complition: complitionHandler)
    }
    
    public func forceStopBuzzzing() {
        DDLogVerbose("Sending Stop Buzzing Command for \(String(describing: basePeripheral.name))")
        let bytes : [UInt8] = [ 0xA1, 0x04 ]
        print(bytes)
        let data = Data(bytes: bytes)
        mainServiceModel.controlPoint = data
        mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID)
    }
    
    public func writeFixFSDError(hardwareRevision:String, modelNumber: String) {
        DDLogVerbose("FDSLog:- Writing FDS Fixes for \(String(describing: basePeripheral.name))")
        DDLogVerbose("FDSLog:- Hardware Revision to write \(String(describing: hardwareRevision))")
        DDLogVerbose("FDSLog:- Model Number to Write  \(String(describing: modelNumber))")
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.deviceServiceModel.pairCodeValue = strongSelf.pairingCode
            strongSelf.deviceServiceModel.writeValue(withUUID: DeviceInfoServiceModelConstants.PairCodeUUID)
            strongSelf.deviceServiceModel.hardwareRevision = hardwareRevision
            strongSelf.deviceServiceModel.writeValue(withUUID: DeviceInfoServiceModelConstants.HardwareRevisionUUID)
            strongSelf.deviceServiceModel.modelNumber = modelNumber
            strongSelf.deviceServiceModel.writeValue(withUUID: DeviceInfoServiceModelConstants.ModelNumberUUID)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
            guard let strongSelf = self else { return }
            DDLogVerbose("FDSLog:- Disconnecting FDS tracker")
            DDLogVerbose("FDSLog:- Before Disconnecing FDS Device Count - \(SLSensorManager.sharedInstance.fdsDevices.count)")
            //SensorManager.sharedInstance.disconnectFromSensor(self)
            strongSelf.disconnectTracker()
            strongSelf.serviceModelManager.resetServices()
            SLSensorManager.sharedInstance.fdsDevices = [TrackerDevice]()
            DDLogVerbose("FDSLog:- After Disconnection FDS Device Count - \(SLSensorManager.sharedInstance.fdsDevices.count)")
            SLSensorManager.sharedInstance.removeOutOfRangeSensor(sensor: strongSelf)
            
            var fixFDSDict: [String: Any] = [:]
            fixFDSDict["UUID"] = strongSelf.trackerUUID
            SLCloudConnector.sharedInstance.updateFDSFixState(fdsDict: fixFDSDict, success: { successResponse in
                DDLogVerbose("FDSLog:- Update fix FDS Error State Sucess => \(String(describing: successResponse))")
            }, failure: { failureDict in
                DDLogVerbose("FDSLog:- Update fix FDS Error State Failed!!!!! => \(String(describing: failureDict?.localizedDescription))")
            })
        }
    }
    
    public func writeSettingsForAdaptiveMode(minMaxBytes:[UInt8]) {
        // data : 0xCB01B0BA
        DDLogVerbose("Writing Adaptive Mode RSSI Settings for \(String(describing: basePeripheral.name))")
        var bytes : [UInt8] = [ 0xCB, 0x01]
        bytes.append(contentsOf: minMaxBytes)
        print(bytes)
        let data = Data(bytes:bytes)
        mainServiceModel.controlPoint = data
        mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID)
    }
    
    // MARK:- Set Alert Mode Actions
    public func turnOnAlertMode(){
        self.setHighAlertMode()
    }
    
    public func setHighAlertMode(){
        DDLogVerbose("Turn ON Alert Mode for \(String(describing: basePeripheral.name))")
        let bytes : [UInt8] = [ 0xA2, 0x03 ]
        print(bytes)
        let data = Data(bytes:bytes)
        mainServiceModel.controlPoint = data
        mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID)
    }
    public func turnOnAlertMode(complitionHandler : @escaping (_ charecterstic:CBCharacteristic) -> Void){
        self.setHighAlertMode(complitionHandler: complitionHandler)
    }
    
    
    public func setHighAlertMode(complitionHandler : @escaping (_ charecterstic:CBCharacteristic) -> Void){
        DDLogVerbose("Turn ON Alert Mode for \(String(describing: basePeripheral.name))")
        let bytes : [UInt8] = [ 0xA2, 0x03 ]
        print(bytes)
        let data = Data(bytes:bytes)
        mainServiceModel.controlPoint = data
        mainServiceModel.setNotify(enabled: true, forUUID: MainServiceModelConstants.customCharUUID)
        mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID, complition: complitionHandler)
    }
    
    public func restoreAlertMode() {
        if self.alertMode == AppConstants.HIGH_ALERT_MODE {
            self.turnOnAlertMode { (charecterstics) in
                DDLogVerbose("Writing Turn On Alert Mode value \(String(describing: charecterstics.value))")
            }
        } else {
            self.turnOffAlertMode { (charecterstics) in
                DDLogVerbose("Writing Turn Off Alert Mode value \(String(describing: charecterstics.value))")
            }
        }
    }
    
    public func turnOffAlertMode(){
        self.setLowMode()
    }
    public func setLowMode(){
        // Write (Data([0x0]))
        DDLogVerbose("Turn OFF Alert Mode for \(String(describing: basePeripheral.name))")
        let bytes : [UInt8] = [ 0xA2, 0x00 ]
        let data = Data(bytes:bytes)
        mainServiceModel.controlPoint = data
        mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID)
    }
    
    public func turnOffAlertMode(complitionHandler : @escaping (_ charecterstic:CBCharacteristic) -> Void){
        self.setLowMode(complitionHandler: complitionHandler)
    }
    
    public func setLowMode(complitionHandler : @escaping (_ charecterstic:CBCharacteristic) -> Void){
        // Write (Data([0x0]))
        DDLogVerbose("Turn OFF Alert Mode for \(String(describing: basePeripheral.name))")
        let bytes : [UInt8] = [ 0xA2, 0x00 ]
        let data = Data(bytes:bytes)
        mainServiceModel.controlPoint = data
        mainServiceModel.setNotify(enabled: true, forUUID: MainServiceModelConstants.customCharUUID)
        mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID, complition: complitionHandler)
    }
    
    
    // MARK:- Ring Service Actions
    public func buzzSensor() {
        // Write (Data([0x1]))
        DDLogVerbose("Turn On Mobile2Sensor Ring for \(String(describing: basePeripheral.name))")
        let bytes : [UInt8] = [ 0xA1, 0x01 ]
        let data = Data(bytes:bytes)
        mainServiceModel.controlPoint = data
        mainServiceModel.setNotify(enabled: true, forUUID: MainServiceModelConstants.customCharUUID)
        mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID)
        
    }
    
    public func blinkAndBuzzSensor(){
        DDLogVerbose("Blink and Buzz Tracker -> \(String(describing: basePeripheral.name))")
        let bytes : [UInt8] = [ 0xA1, 0x03 ]
        let data = Data(bytes:bytes)
        mainServiceModel.controlPoint = data
        mainServiceModel.setNotify(enabled: true, forUUID: MainServiceModelConstants.customCharUUID)
        mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID)
    }
    
    public func blinkAndBuzzSensor(complitionHandler : @escaping (_ charecterstic:CBCharacteristic) -> Void){
        DDLogVerbose("Blink and Buzz Tracker -> \(String(describing: basePeripheral.name))")
        let bytes : [UInt8] = [ 0xA1, 0x03 ]
        print(bytes)
        let data = Data(bytes:bytes)
        
        mainServiceModel.controlPoint = data
        mainServiceModel.setNotify(enabled: true, forUUID: MainServiceModelConstants.customCharUUID)
        mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID, complition: complitionHandler)
    }
    
    public func stopBuzzzing(complitionHandler : @escaping (_ charecterstic:CBCharacteristic) -> Void){
        DDLogVerbose("Sending Stop Buzzing Command for \(String(describing: basePeripheral.name))")
        let bytes : [UInt8] = [ 0xA1, 0x04 ]
        let data = Data(bytes: bytes)
        mainServiceModel.controlPoint = data
        mainServiceModel.setNotify(enabled: true, forUUID: MainServiceModelConstants.customCharUUID)
        mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID, complition: complitionHandler)
        
    }
    
    public func blinkSensor(complitionHandler : @escaping (_ charecterstic:CBCharacteristic) -> Void){
        DDLogVerbose("Blink Tracker -> \(String(describing: basePeripheral.name))")
        let bytes : [UInt8] = [ 0xA1, 0x02 ]
        let data = Data(bytes:bytes)
        mainServiceModel.controlPoint = data
        mainServiceModel.setNotify(enabled: true, forUUID: MainServiceModelConstants.customCharUUID)
        mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID, complition: complitionHandler)
        
    }
    
    public func sleepDevices() {
        
        // Write A2 00
        DDLogVerbose("Turn OFF Blink and BUZZ BOTH \(String(describing: basePeripheral.name))")
        let bytes : [UInt8] = [ 0xA2, 0x00 ]
        print(bytes)
        let data = Data(bytes:bytes)
        mainServiceModel.controlPoint = data
        mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID)
        
    }
    
    public func disconnectTracker() {
        DDLogVerbose("Manually Disconnect Tracker -> Firmware \(String(describing: basePeripheral.name))")
        let bytes : [UInt8] = [ 0xA6, 0x01 ]
        print(bytes)
        let data = Data(bytes:bytes)
        mainServiceModel.controlPoint = data
        mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID)
    }
    
    public func deregisterTracker() {
        DDLogVerbose("DeRegister Tracker -> Power Saving Mode \(String(describing: basePeripheral.name))")
        let bytes : [UInt8] = [ 0xA5, 0x01 ]
        print(bytes)
        let data = Data(bytes:bytes)
        mainServiceModel.controlPoint = data
        mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID)
    }
    public func deregisterTracker(complitionHandler : @escaping (_ charecterstic:CBCharacteristic) -> Void) {
        DDLogVerbose("DeRegister Tracker -> Power Saving Mode \(String(describing: basePeripheral.name))")
        let bytes : [UInt8] = [ 0xA5, 0x01 ]
        print(bytes)
        let data = Data(bytes:bytes)
        mainServiceModel.controlPoint = data
        mainServiceModel.setNotify(enabled: true, forUUID: MainServiceModelConstants.customCharUUID)
        mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID, complition: complitionHandler)
    }
    
    // MARK:-===================== Ring Actions======================
    
    public func stopBuzzing() {
        // Write (Data([0x1]))
        DDLogVerbose("Turn Off Sensor2Mobile Ring for \(String(describing: basePeripheral.name))")
        let bytes : [UInt8] = [ 0xA4, 0x02 ]
        print(bytes)
        let data = Data(bytes:bytes)
        mainServiceModel.controlPoint = data
        mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID)
    }
    
    public func readFirmwareValue() {
        DDLogVerbose("Reading Firmware version for \(String(describing: basePeripheral.name))")
        deviceServiceModel.readValue(withUUID: DeviceInfoServiceModelConstants.FirmwareRevisionUUID)
    }
    
    // MARK:- Turn ON OR Enable Camera Mode
    public func turnOnCameraMode() {
        // Write (Data([0x1]))
        DDLogVerbose("Turn On CameraMode \(String(describing: basePeripheral.name))")
        let bytes : [UInt8] = [ 0xA3, 0x01 ]
        print(bytes)
        let data = Data(bytes:bytes)
        mainServiceModel.controlPoint = data
        mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID)
    }
    
    // MARK:- Turn OFF OR Disable Camera Mode
    public func turnOffCameraMode() {
        // Write (Data([0x0]))
        DDLogVerbose("Turn Off CameraMode \(String(describing: basePeripheral.name))")
        let bytes : [UInt8] = [ 0xA3, 0x02 ]
        print(bytes)
        let data = Data(bytes:bytes)
        mainServiceModel.controlPoint = data
        mainServiceModel.writeValue(withUUID: MainServiceModelConstants.customCharUUID)
    }
}

extension TrackerDevice: CBPeripheralDelegate {
    override open func isEqual(_ object: Any?) -> Bool {
        if let otherPeripheral = object as? TrackerDevice {
            return basePeripheral == otherPeripheral.basePeripheral
        }
        return false
    }
}
