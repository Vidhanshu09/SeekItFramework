//
//  SLSensorManager.swift
//  SeekLib
//
//  Created by Jitendra Chamoli on 08/10/18.
//

import Foundation
import CoreBluetooth
import iOSDFULibrary
import Signals
import Locksmith
import SwiftyJSON
import CocoaLumberjack

/**
 An extensible Bluetooth LE Sensor Manager with concrete Service and Characteristic types, hierarchy, forwarding and observation to simplify BLE.
 */
public class SLSensorManager: NSObject {
    
    /**
     This is a lazy instance. You can opt to NOT call it and control the lifecycle of the SensorManager yourself if desired.
     
     No internal reference is made to this instance.
     */
    public static let sharedInstance = SLSensorManager()
    
    /**
     Delegate that any class can use to Bluetooth State
     */
    public weak var delegate: SLSensorManagerDelegate?
    
    /**
     lazy DispatchQueue, on which Central Manager will communicate in the background as well
     */
    private var dispatchQueue:DispatchQueue {
        let concurrentQueue = DispatchQueue(label: ManagerConstants.dispatchQueueLabel, attributes: .concurrent)
        return concurrentQueue
    }
    
    public var keyChainIDHashMap:[String: Any]? {
        return Locksmith.loadDataForUserAccount(userAccount: Bundle.main.object(forInfoDictionaryKey:"CFBundleName") as! String)
    }
    /**
     Options that can be passed while intializing Central Manager
     */
    private let restoreOptions:[String: Any] = [CBCentralManagerOptionRestoreIdentifierKey: ManagerConstants.restoreIdentifier]
    private var filterUUID: [CBUUID]!
    
    // Filter these BLE services
    let ledService          = CBUUID(string: LedServiceModelConstants.serviceUUID)
    let alertService        = CBUUID(string: AlertServiceModelConstants.serviceUUID)
    let cameraService       = CBUUID(string: CameraServiceModelConstants.serviceUUID)
    let mainService         = CBUUID(string: MainServiceModelConstants.serviceUUID)
    
    // define our scanning interval times
    let timerPauseInterval:TimeInterval = 10.0
    let timerScanInterval:TimeInterval = 20.0
    var lastScanTime:Date?
    
    let secureDFUUUID       = CBUUID(string: "FE59")
    let seekitSensorsUUID   = CBUUID(string: "AAAA")
    
    public var shouldOnlyScanDFUSensors: Bool = false {
        didSet {
            sensorsById.removeAll()
        }
    }

    public var lastConnectedSensors:[CBPeripheral]?
    /// Customizable Sensor Class Type
    public var appLaunchedUsingBGMode: Bool = false
    public var updatingDFUDevice: Bool = false
    var autoUpdatetimer: DispatchSourceTimer?
    var updateLocationStatustimer: DispatchSourceTimer?
    let locationManager = SLLocationManager.sharedInstance
    
    // DFU *********
    public var dfuController      : DFUServiceController?
    public var selectedFirmware   : DFUFirmware?
    public var selectedFileURL    : URL?
    public var selectedDevice: TrackerDevice?
    public var selectedPeripheral : CBPeripheral?
    public var uploadStatus: String!
    // DFU *********
    
    /**
     All SensorManager logging is directed through this closure. Set it to nil to turn logging off
     or set your own closure at the project level to direct all logging to your logger of choice.
     */
    public static var logSensorMessage: ((_: String) -> ())? = { message in
        DDLogVerbose(message)
    }
    
    /**
     Initializes the Sensor Manager.
     
     - parameter background: Whether the system should init central Manager with background mode
     if Bluetooth is powered off when the central manager is instantiated.
     
     - returns: Sensor Manager instance
     */
    public init(background: Bool = true) {
        super.init()
        DDLogVerbose("Starting Sensor Manager instance")
        let options:[String: Any]? = background ? [CBCentralManagerScanOptionAllowDuplicatesKey: NSNumber(booleanLiteral: true), CBCentralManagerOptionRestoreIdentifierKey: ManagerConstants.restoreIdentifier] : nil
        sensorsById = [:]
        centralManager = CBCentralManager(delegate: self, queue: dispatchQueue, options: options)
        filterUUID = [CBUUID]()
        filterUUID.append(mainService)
    }
    
    convenience init(centralManager: CBCentralManager) {
        self.init(background: true)
        centralManager.delegate = self
        self.centralManager = centralManager
        DDLogVerbose("Starting Sensor Manager convenience init(centralManager: ")
    }
    
    // MARK: - Bluetooth scanning
    
    @objc func pauseScan() {
        // Scanning uses up battery on phone, so pause the scan process for the designated interval.
        if updatingDFUDevice == false /*&& TAAudioPlayer.sharedInstance.isOnPhoneCall == false*/ {
            DDLogVerbose("*** PAUSING SCAN...")
            stopScan()
            DDLogVerbose("PAUSESCAN Sensor Manager -> isScanning \(String(describing: centralManager?.isScanning))")
        }
    }
    
    func clearOutOfRangeDevices() {
        DDLogVerbose("Refresh Found List - Clear Any Out of Range devices")
        for foundDevice in foundDevices {
            if foundDevice.basePeripheral.state != .connected {
                if let seconds = Date().seconds(sinceDate:foundDevice.timeStamp), seconds > 120 {
                    self.removeOutOfRangeSensor(sensor: foundDevice)
                }
            }
        }
        
        for secureDFUDevice in dfuFailedDevices {
            if let seconds = Date().seconds(sinceDate:secureDFUDevice.timeStamp), seconds > 30 {
                self.removeOutOfRangeDFUFailedSensor(sensor: secureDFUDevice)
            }
        }
    }
    
    public func safeZoneAction() {
        if !isPickPocketModeActivated() && !isSleepModeActivated() && !isDNDModeActivated() {
            if isWifiModeActivated() {
                makeDevicesSleep()
            } else {
                restoreSleepDevices()
            }
        }
    }
    
    //    func pickPocketEnable(){ //Not Working
    //        DDLogVerbose("******** pickpocketEnable ********")
    //        foundDevices.filter {($0.basePeripheral.state == CBPeripheralState.connected )}.forEach { connectedDevice in
    //            connectedDevice.turnOnAlertMode()
    //            connectedDevice.setPickPocketModeValues()
    //        }
    //    }
    
    public func makeDevicesSleep() {
        DDLogVerbose("******** makeDevicesSleep ********")
        foundDevices.filter {($0.basePeripheral.state == CBPeripheralState.connected )}.forEach { connectedDevice in
            
            connectedDevice.writeQueue.addOperation(operation: Operation.init(bleTracker: connectedDevice, type: OperationType.TurnOffAlertMode, complitionHandler: {
                print("Writing turn off Alert value for sensor \(connectedDevice.deviceNickName)")
            }))
            
            connectedDevice.writeQueue.addOperation(operation: Operation.init(bleTracker: connectedDevice, type: OperationType.BetterAdaptiveMode, complitionHandler: {
                print("Writing Better Adaptive value for sensor \(connectedDevice.deviceNickName)")
            }))
            if !connectedDevice.writeQueue.isInProcess {
                connectedDevice.writeQueue.invokeQueue()
            }
        }
    }
    
    public func restoreSleepDevices() {
        DDLogVerbose("******** restoreSleepDevices ********")
        foundDevices.filter {($0.basePeripheral.state == CBPeripheralState.connected )}.forEach { connectedDevice in
            
            if isPickPocketModeActivated() {
                connectedDevice.writeQueue.addOperation(operation: Operation.init(bleTracker: connectedDevice, type: OperationType.TurnOnAlertMode, complitionHandler: {
                    print("Writing turn On Alert value for sensor \(connectedDevice.deviceNickName)")
                }))
            } else {
                connectedDevice.restoreAlertMode()
            }
            
            connectedDevice.writeQueue.addOperation(operation: Operation.init(bleTracker: connectedDevice, type: OperationType.BetterAdaptiveMode, complitionHandler: {
                print("Writing Better Adaptive mode value on sensor \(connectedDevice.deviceNickName)")
            }))
            if !connectedDevice.writeQueue.isInProcess{
                connectedDevice.writeQueue.invokeQueue()
            }
        }
    }
    
    public func restorePickPocketValues() {
        SLSensorManager.sharedInstance.foundDevices.forEach { connectedDevice in
            //connectedDevice.alertMode = 0
            print("BEFORE RESTORE restorePickPocketValues ===> TEMP \(connectedDevice.tempAlertMode) and ALERT \(connectedDevice.alertMode)")
            connectedDevice.alertMode = connectedDevice.tempAlertMode
            
            connectedDevice.tempAlertMode = AppConstants.LOW_ALERT_MODE
            connectedDevice.setPickPocketModeValues(complitionHandler: {_ in
                connectedDevice.restoreAlertMode()
            })
            print("AFTER RESTORE restorePickPocketValues ===> TEMP \(connectedDevice.tempAlertMode) and ALERT \(connectedDevice.alertMode)")
        }
    }
    
    public func restoreSleepDevicesOverride() {
        SLSensorManager.sharedInstance.foundDevices.forEach { connectedDevice in
            print("BEFORE RESTORE restoreSleepDevicesOverride ===> TEMP \(connectedDevice.tempAlertMode) and ALERT \(connectedDevice.alertMode)")
            
            connectedDevice.tempAlertMode = connectedDevice.alertMode
            connectedDevice.alertMode = AppConstants.HIGH_ALERT_MODE
            if (connectedDevice.basePeripheral.state == CBPeripheralState.connected ){
                connectedDevice.restoreAlertMode()
            }
            print("AFTER RESTORE restoreSleepDevicesOverride ===> TEMP \(connectedDevice.tempAlertMode) and ALERT \(connectedDevice.alertMode)")
            
        }
    }
    
    public func restorePickPocketValue(uuid: String) {
        foundDevices.filter {
            ($0.basePeripheral.state == CBPeripheralState.connected && $0.trackerUUID == uuid)}.forEach { connectedDevice in
                connectedDevice.setPickPocketModeValues(complitionHandler: { (char) in
                    if (connectedDevice.alertMode == AppConstants.LOW_ALERT_MODE) {
                        connectedDevice.setLowMode(complitionHandler: {_ in
                            
                        })
                    } else {
                        connectedDevice.setHighAlertMode(complitionHandler: {_ in
                            
                        })
                    }
                    
                })
        }
    }
    
    public func isPendingFirmwareUpdateForAnyConnectedTracker() -> Bool {
        
        if !SLSensorManager.sharedInstance.updatingDFUDevice {
            for dev in SLSensorManager.sharedInstance.foundDevices {
                if dev.basePeripheral.state == .connected {
                    if let deviceArray = SLCloudConnector.sharedInstance.devicesList?.sensorArray, let mainDevice = deviceArray.filter( {$0.UUID! == String((dev.seekitUUID))}).first, let currentFirmware = mainDevice.deviceFirmwareVersion {
                        if currentFirmware.count > 1 && currentFirmware.count > 1 &&
                            currentFirmware != SLCloudConnector.sharedInstance.latestFirmwareVersion {
                            // DFU Update is pending for one of the sensor
                            return true
                        }
                    }
                }
            }
        }
        return false
    }
    
    public func isSleepModeActivated() -> Bool {
        
        /*if let userId = CloudConnector.sharedInstance.userProfile?.userId {
         let sleepData = RealmManager.sharedInstance.readSleepRecord(userID: userId.stringValue)
         if (sleepData?.isSleepOverrideEnabled == true){
         return true
         }
         }
         let now = NSDate()
         let calendar = Calendar(identifier: Calendar.Identifier.gregorian)
         let nowDateValue = now as Date
         let formatter = DateFormatter()
         formatter.dateFormat = "EE"
         let dayInWeek = formatter.string(from: nowDateValue)
         
         // Calculate
         if let sleepModel = CloudConnector.sharedInstance.sleeptime, let startDNDTime = sleepModel.startDNDTime, let endDNDTime = sleepModel.endDNDTime {
         //let calendar = Calendar.current
         let endHour = calendar.component(.hour, from: endDNDTime)
         let endMinutes = calendar.component(.minute, from: endDNDTime)
         let startHour = calendar.component(.hour, from: startDNDTime)
         let startMinutes = calendar.component(.minute, from: startDNDTime)
         let isWeekEndActivated = sleepModel.isWeekEndEnabled
         let daysSelection = sleepModel.dateSelection.components(separatedBy: ",")
         print(startHour, startMinutes, endHour, endMinutes, isWeekEndActivated)
         
         if isWeekEndActivated && calendar.isDateInWeekend(now as Date) {
         return true
         }
         
         if (daysSelection.contains(dayInWeek.lowercased())){
         if startHour < endHour {
         let startTime = calendar.date(bySettingHour: startHour, minute: startMinutes, second: 0, of: nowDateValue)
         let endTime = calendar.date(bySettingHour: endHour, minute: endMinutes, second: 0, of: nowDateValue)
         
         if nowDateValue >= startTime! &&
         nowDateValue <= endTime! {        // date is in range
         return true && sleepModel.isDNDEnabled
         }
         } else if startHour > endHour {
         let startTime = calendar.date(bySettingHour: startHour, minute: startMinutes, second: 0, of: nowDateValue)
         let endTime = calendar.date(bySettingHour: endHour, minute: endMinutes, second: 0, of: nowDateValue.tomorrow)
         //calendar.date(bySettingHour: endHour, minute: endMinutes, second: 0, of: nowDateValue)
         if nowDateValue >= startTime! &&
         nowDateValue <= endTime! {        // date is in range
         return true && sleepModel.isDNDEnabled
         }
         } else if startHour == endHour {
         let startTime = calendar.date(bySettingHour: startHour, minute: startMinutes, second: 0, of: nowDateValue)
         let endTime = calendar.date(bySettingHour: endHour, minute: endMinutes, second: 0, of: nowDateValue)
         
         if nowDateValue >= startTime! &&
         nowDateValue <= endTime! {        // date is in range
         return true && sleepModel.isDNDEnabled
         }
         }
         }
         }
         return false*/
        return (UserDefaults.standard.bool(forKey: "EnabledDND") == true)
    }
    
    public func isWifiModeActivated() -> Bool {
        
        let connectedWifiDict =  SSID.fetchSSIDInfo()
        if let currentConnectedWifiBSSID = connectedWifiDict["BSSID"] as? String {
            if let wifiRecord =  SLRealmManager.sharedInstance.readWiFiRecords().filter({($0.wifiBSSID == currentConnectedWifiBSSID )}).first {
                if wifiRecord.isEnabled {
                    return true
                }
            }
        }
        return false
    }
    
    public func isPickPocketModeActivated() -> Bool {
        
        return (UserDefaults.standard.bool(forKey: "PickPocketValue") == true)
    }
    
    public func isDNDModeActivated() -> Bool {
        return (UserDefaults.standard.bool(forKey: "DNDValue") == true)
    }
    
    public func autoScanCheck(){
        guard self.lastScanTime != nil else {
            self.lastScanTime = Date()
            return
        }
        let currentTime = Date()
        if currentTime.timeIntervalSince(self.lastScanTime!) >= timerScanInterval + timerPauseInterval {
            self.lastScanTime = currentTime
            resumeScan()
        }
    }
    
    @objc func resumeScan() {
        // Start scanning again...
        DispatchQueue.main.asyncAfter(deadline: .now() + timerScanInterval) {
            self.pauseScan()
        }
        self.clearOutOfRangeDevices()
        if updatingDFUDevice == false /*&& TAAudioPlayer.sharedInstance.isOnPhoneCall == false */{
            DDLogVerbose("*** RESUMING SCAN!")
            stateUpdated()
            DDLogVerbose("resumeScan Sensor Manager -> isScanning \(String(describing: centralManager?.isScanning))")
        }
    }
    
    public func generateUniqueDeviceID() -> String {
        //        if #available(iOS 11.0, *) {
        //            /*DCDevice.current.generateToken {
        //             (data, error) in
        //             guard let data = data else {
        //             return
        //             }
        //             let token = data.base64EncodedString()
        //             print("********")
        //             print(token)
        //             print("********")
        //             }*/
        //        } else {
        //            // Fallback on earlier versions
        //            print("Handle Device Token for IOS 10 and IOS 9")
        //        }
        //        let UUIDValue = UIDevice.current.identifierForVendor!.uuidString
        //        print("UUID: \(UUIDValue)")
        return UIDevice.current.identifierForVendor!.uuidString
    }
    
    /// Sensor Manager State
    public enum ManagerState {
        /// Off
        case off
        /// On, Scanning Disabled
        case idle
        /// Passive Scan for BLE sensors
        case passiveScan
        /// Aggressive Scan for BLE sensors
        case aggressiveScan
    }
    
    /// Device's Bluetooth Radio Status
    public var bluetoothEnabled: Bool {
        return centralManager.state == .poweredOn
    }
    
    /// Current Sensor Manager Scanning State
    public var scannerState: ManagerState = .off {
        didSet {
            if oldValue != scannerState {
                DDLogVerbose("Scanner State Changed")
                stateUpdated()
            }
        }
    }
    
    /// Customizable Sensor Class Type
    public var SensorType: TrackerDevice.Type = TrackerDevice.self
    
    /**
     All Discovered Sensors.
     
     Note: sensors may no longer be connectable. Call `removeInactiveSensors` to trim.
     */
    //public(set) open var foundDevices: [TrackerDevice] = [TrackerDevice]()
    
    public var foundDevices: [TrackerDevice] {
        return Array(sensorsById.values)
    }
    
    public var dfuFailedDevices: [TrackerDevice] {
        return Array(dfuSensorsId.values)
    }
    
    public var fdsDevices: [TrackerDevice] = [TrackerDevice]()
    
    /**
     Retrieve All Connected Sensors.
     */
    open func getConnectedPeripherals() -> [CBPeripheral] {
        guard let bluetoothManager = centralManager else {
            return []
        }
        
        var retreivedPeripherals : [CBPeripheral]
        retreivedPeripherals = [CBPeripheral]()
        retreivedPeripherals    = bluetoothManager.retrieveConnectedPeripherals(withServices: filterUUID)
        for peripheral in retreivedPeripherals{
            guard let peripheralUUID = UserDefaults.standard.string(forKey: peripheral.identifier.uuidString) else {
                continue
            }
            if sensorForPeripheral(peripheral, create: true, trackerID: peripheralUUID) != nil {
                //                if trackerDevice.basePeripheralState != "connected" {
                //                    trackerDevice.basePeripheral.delegate = trackerDevice.serviceModelManager
                //                    self.connectToSensor(trackerDevice)
                //                    trackerDevice.peripheralStateChanged()
                //                }
            }
        }
        return retreivedPeripherals
    }
    
    // MARK: CBCentralManagerDelegate - willRestoreState for Peripheral
    
    @objc public func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        DDLogVerbose("willRestoreState: \(String(describing: dict[CBCentralManagerRestoredStatePeripheralsKey]))")
        // Clear any connected peripheral
        if let connectedLastTrackers:[CBPeripheral] = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral], connectedLastTrackers.count > 0 {
            lastConnectedSensors = []
            //lastConnectedSensors = connectedLastTrackers
            connectedLastTrackers.forEach({ pendingPeripheral in
                DDLogVerbose("Forgot to cancel connected sensor \(String(describing: pendingPeripheral.name)) last time")
                lastConnectedSensors?.append(pendingPeripheral)
            })
        }
    }
    
    /**
     Set the Service Types to scan for. Will also create the Services when discovered.
     
     - parameter serviceTypes: Service Types Array
     */
    //    public func setServicesToScanFor(_ serviceTypes: [ServiceProtocol.Type]) {
    //        addServiceTypes(serviceTypes)
    //        serviceFactory.servicesToDiscover = serviceTypes.map { type in
    //            return CBUUID(string: type.uuid)
    //        }
    //    }
    
    /**
     Add Service Types to Create when discovered after connecting to a Sensor.
     
     - parameter serviceTypes: Service Types Array
     */
    //    public func addServiceTypes(_ serviceTypes: [ServiceProtocol.Type]) {
    //        for type in serviceTypes {
    //            serviceFactory.serviceTypes[type.uuid] = type.serviceType
    //        }
    //    }
    
    /**
     Attempt to connect to a sensor.
     
     - parameter sensor: The sensor to connect to.
     */
    public func connectToSensor(_ sensor: TrackerDevice) {
        if bluetoothEnabled{
            SLSensorManager.logSensorMessage?("SensorManager: Connecting to sensor ...")
            self.centralManager.connect(sensor.basePeripheral, options:nil)
        }
    }
    
    /**
     Disconnect from a sensor.
     
     - parameter sensor: The sensor to disconnect from.
     */
    public func disconnectFromSensor(_ sensor: TrackerDevice) {
        SLSensorManager.logSensorMessage?("SensorManager: Disconnecting from sensor ...")
        centralManager.cancelPeripheralConnection(sensor.basePeripheral)
    }
    
    /**
     Removes inactive sensors from the Sensor Manager.
     
     - parameter inactiveTime: Trim sensors that have not communicated
     with the Sensor Manager with the last `inactiveTime` TimeInterval
     */
    public func removeInactiveSensors(_ inactiveTime: TimeInterval) {
        let now = Date.timeIntervalSinceReferenceDate
        for sensor in foundDevices {
            if now - sensor.lastSensorActivity > inactiveTime {
                if let sensor = sensorsById.removeValue(forKey: sensor.basePeripheral.identifier.uuidString) {
                    onSensorRemoved => sensor
                }
            }
        }
    }
    
    public func removeOutOfRangeSensor(sensor: TrackerDevice) {
        if let sensor = sensorsById.removeValue(forKey: sensor.basePeripheral.identifier.uuidString) {
            onSensorRemoved => sensor
        }
        sensor.basePeripheralState = .disconnected
    }
    
    public func removeOutOfRangeDFUFailedSensor(sensor: TrackerDevice) {
        if let sensor = dfuSensorsId.removeValue(forKey: sensor.basePeripheral.identifier.uuidString) {
            onSensorRemoved => sensor
        }
    }
    
    public func startAutoConnectTimer() {
        //        if TAAudioPlayer.sharedInstance.isOnPhoneCall == true {
        //            return
        //        }
        if bluetoothEnabled != true {
            // Return if Bluetooth is turned off
            return
        }
        //DDLogVerbose("startAutoConnectTimer started")
        let queue = DispatchQueue(label: "com.panasonic.trackerapp.timer", attributes: .concurrent)
        autoUpdatetimer?.cancel()        // cancel previous timer if any
        autoUpdatetimer = DispatchSource.makeTimerSource(queue: queue)
        autoUpdatetimer?.schedule(deadline: .now(), repeating: .seconds(10), leeway: .milliseconds(100))
        autoUpdatetimer?.setEventHandler { [weak self] in // `[weak self]` only needed if you reference `self` in this closure and you want to prevent strong reference cycle
            //DDLogVerbose("startAutoConnectTimer Task Triggered")
            self?.autoScanCheck()
            self?.connectSensors()
        }
        autoUpdatetimer?.resume()
    }
    
    public func stopAutoConnectTimer() {
        //DDLogVerbose("startAutoConnectTimer Cancelled")
        autoUpdatetimer?.cancel()
        autoUpdatetimer = nil
    }
    
    
    func connectSensors() {
        //DDLogVerbose("Sensor Manager -> Connect Sensor Called")
        if updatingDFUDevice {
            DDLogVerbose("DFU in progress can not connect other devices")
            return
        }
        DDLogVerbose("Sensor Manager -> Found Sensors Count \(self.foundDevices.count)")
        DDLogVerbose("Sensor Manager -> isScanning \(String(describing: centralManager!.isScanning))")
        DDLogVerbose("Sensor Manager -> Connected Sensors Count \(self.getConnectedPeripherals().count)")
        if let sensorArray = SLCloudConnector.sharedInstance.devicesList?.sensorArray {
            sensorArray.forEach({ device in
                var count = 0
                let previousStatus = device.connectionStatus
                for foundDevice in foundDevices {
                    if String(foundDevice.seekitUUID) == device.UUID! {
                        // When Some sensor is found and it is not connected -> Connect
                        count += 1
                        if let pairingKey = device.passKey {
                            foundDevice.pairingCode =  pairingKey.stringValue
                            if let buzzTime = device.buzzTime?.stringValue {
                                foundDevice.buzzTime =  buzzTime
                            }
                            foundDevice.deviceNickName = device.trackerName ?? "Panasonic"
                        }
                        if let alertMode = device.alertMode {
                            foundDevice.alertMode = alertMode
                        }
                        if let sharedState = device.sharedState, let currentUserID = UserDefaults.standard.string(forKey: AppConstants.userIDKey) {
                            if ((foundDevice.basePeripheral.state != .connected
                                && foundDevice.basePeripheral.state != .disconnecting
                                && bluetoothEnabled
                                && centralManager?.state == .poweredOn
                                && device.autoConnect && !sharedState) || (foundDevice.basePeripheral.state != CBPeripheralState.connected
                                    && foundDevice.basePeripheral.state != CBPeripheralState.disconnecting
                                    && self.bluetoothEnabled
                                    && centralManager?.state == .poweredOn
                                    && device.autoConnect && sharedState && device.sharedUserId == currentUserID)) {
                                if foundDevice.basePeripheral.state == CBPeripheralState.connecting {
                                    // IMPORTANT, to clear off any pending connections before connecting sensor
                                    //foundDevice.serviceModelManager.resetServices()
                                    // Reset Connection if it still in connecting status
                                    //centralManager.cancelPeripheralConnection(foundDevice.basePeripheral)
                                } else {
                                    // Reset All Services Before Connecting
                                    foundDevice.serviceModelManager.resetServices()
                                }
                                DDLogVerbose("Sensor Manager -> Connect to \(foundDevice.basePeripheral.name!)")
                                connectToSensor(foundDevice)
                            }
                        }
                        
                        let state = (foundDevice.basePeripheral.state, foundDevice.basePeripheralState)
                        
                        switch state {
                        case (.connected,_):
                            if device.lostMode == 2 {
                                self.updateTrackerInfo(sensor: device)
                            }
                            device.connectionStatus = "connected"
                            device.uploadStatus = nil
                            device.progressLabel = nil
                            foundDevice.basePeripheralState = .connected
                            foundDevice.basePeripheral.delegate = foundDevice.serviceModelManager
                            if bluetoothEnabled && self.centralManager.state == .poweredOn && device.batteryLevel == nil {
                                foundDevice.batteryServiceModel.readValue(withUUID: BatteryServiceModelConstants.batteryLevelUUID)
                            }
                            if !self.updatingDFUDevice {
                                if let firmwareVersion = device.deviceFirmwareVersion, firmwareVersion.count > 1, firmwareVersion != SLCloudConnector.sharedInstance.latestFirmwareVersion {
                                    NotificationCenter.default.post(
                                        name: Notification.Name(rawValue: ManagerConstants.pendingFirmwareUpdtNotifyKey), object: nil, userInfo: nil)
                                }
                            }
                        case (_,.connecting):
                            if device.connectionStatus != "lost" {
                                device.connectionStatus = "connecting"
                                foundDevice.basePeripheralState = .connecting
                            }
                        case (.disconnected,_):
                            if device.connectionStatus != "disconnected" && device.connectionStatus != "lost" {
                                device.connectionStatus = "disconnected"
                                foundDevice.basePeripheralState = .disconnected
                                
                                DispatchQueue.main.async {
                                    NotificationCenter.default.post(
                                        name: Notification.Name(rawValue: ManagerConstants.refreshStatusKey), object: nil, userInfo: nil)
                                }
                                DDLogVerbose("\(device.trackerName!) disconnected")
                                if device.autoConnect == true && !isSleepModeActivated() && !isWifiModeActivated(){
                                    SLNotificationsManager.sharedInstance.scheduleDisconnectNotification(message: "\(String(describing: device.trackerName!.trimWhiteSpace())) has been disconnected. Please mark lost to get notification from server", body: "", trackerID: String(foundDevice.seekitUUID), alertMode: device.alertMode!, ringUrl: device.customRingtoneURL ?? "", ringName: device.ringToneName ?? "")
                                }
                            }
                        case (_, .disconnecting):
                            device.connectionStatus = "disconnecting"
                            foundDevice.basePeripheralState = .disconnecting
                        default:
                            break
                        }
                    }
                }
                if count == 0 {
                    if device.connectionStatus != "disconnected" && device.connectionStatus != "lost" && self.disconnectTimerById[device.UUID ?? ""] == nil {
                        device.connectionStatus = "disconnected"
                    }
                }
                if previousStatus != device.connectionStatus {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: Notification.Name(rawValue: ManagerConstants.refreshStatusKey), object: nil, userInfo: nil)
                        NotificationCenter.default.post(
                            name: Notification.Name(rawValue: "TrackerMapUpdate"), object: nil, userInfo: nil)
                        NotificationCenter.default.post(
                            name: Notification.Name(rawValue: "UpdateDetailsConnectionStatus"), object: nil, userInfo: nil)
                    }
                }
            })
        }
    }
    
    public func startLocationUpdator() {
        
        if bluetoothEnabled != true {
            // Return if Bluetooth is turned off
            return
        }
        //DDLogVerbose("startAutoConnectTimer started")
        DispatchQueue.main.async {
            let queue = DispatchQueue(label: "com.panasonic.trackerapp.UpdateTimer", attributes: .concurrent)
            self.updateLocationStatustimer?.cancel()        // cancel previous timer if any
            self.updateLocationStatustimer = DispatchSource.makeTimerSource(queue: queue)
            self.updateLocationStatustimer?.schedule(deadline: .now(), repeating: .seconds(100), leeway: .milliseconds(100))
            self.updateLocationStatustimer?.setEventHandler { [weak self] in
                // `[weak self]` only needed if you reference `self` in this closure and you want to prevent strong reference cycle
                guard let strongSelf = self else { return }
                DDLogVerbose("startLocationUpdator Task Triggered")
                strongSelf.updateSensorLocations()
            }
            self.updateLocationStatustimer?.resume()
        }
    }
    
    public func stopLocationUpdator() {
        DispatchQueue.main.async {
            DDLogVerbose("LocationUpdator Cancelled")
            self.updateLocationStatustimer?.cancel()
            self.updateLocationStatustimer = nil
        }
    }
    
    func updateSensorLocations() {
        let locationManager = SLLocationManager.sharedInstance
        let cloudConnector = SLCloudConnector.sharedInstance
        let currentLocationLat = locationManager.latitudeAsString
        let currentLocationLong = locationManager.longitudeAsString
        var locationDict: [String: Any] = [:]
        locationDict["latitude"] = currentLocationLat
        locationDict["longitude"] = currentLocationLong
        locationDict["distance"] = 50
        
        for foundDevice in foundDevices {
            if foundDevice.basePeripheralState == .connected {
                var updateDict: [String: Any] = [:]
                updateDict["UUID"] = foundDevice.seekitUUID
                updateDict["location"] = locationDict
                updateLocalSensorLocation(trackerID: String(foundDevice.seekitUUID), latitude: locationManager.latitude, longitude: locationManager.longitude)
                cloudConnector.updateTrackerLocation(locationDict: updateDict, success: { (successDict) in
                    DDLogVerbose("**** updateSensorLocations -> Success for \(String(foundDevice.seekitUUID)) **** ")
                }, failure: { error in
                    DDLogVerbose("**** updateSensorLocations -> Failed for \((String(describing: error?.localizedDescription))) **** ")
                })
            }
        }
        updateMyDeviceLocation() // Update current phone's location where App is installed
    }
    
    public func updateMyDeviceLocation() {
        if let retriveuuid = keyChainIDHashMap?["deviceUniqueID"] as? String, let name = keyChainIDHashMap?["deviceName"] as? String  {
            let locationManager = SLLocationManager.sharedInstance
            let cloudConnector = SLCloudConnector.sharedInstance
            let currentLocationLat = locationManager.latitudeAsString
            let currentLocationLong = locationManager.longitudeAsString
            var locationDict: [String: Any] = [:]
            locationDict["latitude"] = currentLocationLat
            locationDict["longitude"] = currentLocationLong
            locationDict["distance"] = 50
            
            var updateDict: [String: Any] = [:]
            updateDict["UUID"] = retriveuuid
            updateDict["location"] = locationDict
            cloudConnector.updateTrackerLocation(locationDict: updateDict, success: { (successDict) in
                DDLogVerbose("**** updating current device location -> Success for uniqueid: \(String(retriveuuid)) deviceName: \(name)**** ")
            }, failure: { error in
                DDLogVerbose("**** updatting current device location -> Failed for uniqueid: \((String(describing: retriveuuid))) deviceName: \(name)**** ")
            })
        }
    }
    
    public func updateLocalSensorLocation(trackerID: String, latitude: Double, longitude: Double) {
        DDLogVerbose("**** updateLocalSensorLocation on Disconnect connection for \(trackerID) **** ")
        let location = TrackerLastKnownLocation()
        location.sensorUUID = trackerID
        location.latitude = latitude
        location.longitude = longitude
        location.time = DateUtility.dateFormatter.string(from: Date())
        SLRealmManager.sharedInstance.writeTrackerLastKnownLocation(location: location)
    }
    
    public func updateSensorLocation(trackerID: String) {
        let locationManager = SLLocationManager.sharedInstance
        let cloudConnector = SLCloudConnector.sharedInstance
        let currentLocationLat = locationManager.latitudeAsString
        let currentLocationLong = locationManager.longitudeAsString
        var locationDict: [String: Any] = [:]
        locationDict["latitude"] = currentLocationLat
        locationDict["longitude"] = currentLocationLong
        locationDict["distance"] = 50
        if let record = SLRealmManager.sharedInstance.readTrackerLastKnownLocation(sensorUUID: trackerID).first {
            locationDict["latitude"] = record.latitude
            locationDict["longitude"] = record.longitude
            SLSensorManager.sharedInstance.updateLocalSensorLocation(trackerID: record.sensorUUID, latitude: record.latitude, longitude: record.longitude)
        }
        
        if let device = self.foundDevices.filter( { $0.seekitUUID == trackerID }).first {
            var updateDict: [String: Any] = [:]
            updateDict["UUID"] = device.seekitUUID
            updateDict["location"] = locationDict
            cloudConnector.updateTrackerLocation(locationDict: updateDict, success: { (successDict) in
                DDLogVerbose("**** updateSensorLocations on lost connection -> Success for \(device.seekitUUID)) **** ")
            }, failure: { error in
                //DDLogVerbose("**** updateSensorLocations on Disconnection -> Failed for \((String(describing: error?.localizedDescription))) **** ")
            })
        }
    }
    
    /// Bluetooth State Change Signal
    public let onBluetoothStateChange = Signal<CBManagerState>()
    
    /// Sensor Discovered Signal
    public let onSensorDiscovered = Signal<TrackerDevice>()
    
    /// Sensor Connected Signal
    public let onSensorConnected = Signal<TrackerDevice>()
    
    /// Sensor Connection Failed Signal
    public let onSensorConnectionFailed = Signal<TrackerDevice>()
    
    /// Sensor Disconnected Signal
    public let onSensorDisconnected = Signal<(TrackerDevice, NSError?)>()
    
    /// Sensor Removed Signal
    public let onSensorRemoved = Signal<TrackerDevice>()
    
    //////////////////////////////////////////////////////////////////
    // Private / Internal Classes, Properties and Constants
    //////////////////////////////////////////////////////////////////
    
    public var centralManager: CBCentralManager!
    
    fileprivate var sensorsById = Dictionary<String, TrackerDevice>()
    fileprivate var dfuSensorsId = Dictionary<String, TrackerDevice>()
    fileprivate var disconnectTimerById = Dictionary<String, Timer>()
    fileprivate var disconnectBufferFirmwareVersion = [4, 4, 8] //Firmware version that changes buffer in disconnect
    fileprivate var activityUpdateTimer: Timer?
    static internal let RSSIPingInterval: TimeInterval = 2
    static internal let ActivityInterval: TimeInterval = 5
    static internal let InactiveInterval: TimeInterval = 6
}

// Private Funtions
extension SLSensorManager {
    
    fileprivate func stateUpdated() {
        
        if centralManager != nil && centralManager?.state != .poweredOn {
            self.delegate?.manager(self, powerState: false)
            return
        }
        
        activityUpdateTimer?.invalidate()
        activityUpdateTimer = nil
        
        switch scannerState {
        case .off:
            stopScan()
            
            for sensor in foundDevices {
                disconnectFromSensor(sensor)
                sensor.serviceModelManager.resetServices()
            }
            DDLogVerbose("Shutting Down SensorManager")
            
        case .idle:
            stopScan()
            startActivityTimer()
            
        case .passiveScan:
            scan(false)
            startActivityTimer()
            
        case .aggressiveScan:
            DDLogVerbose("Scanner State Aggressive Scan")
            scan(true)
            startActivityTimer()
        }
    }
    
    public func stopScan() {
        DDLogVerbose("SensorManager: Stop Scan")
        centralManager?.stopScan()
    }
    
    public func startScan() {
        DDLogVerbose("SensorManager: Start Scan")
        if centralManager?.state == .poweredOn {
            scan(true)
        }
    }
    
    fileprivate func startActivityTimer() {
        activityUpdateTimer?.invalidate()
        activityUpdateTimer = Timer.scheduledTimer(timeInterval: SLSensorManager.ActivityInterval, target: self, selector: #selector(rssiUpateTimerHandler(_:)), userInfo: nil, repeats: true)
    }
    
    fileprivate func scan(_ aggressive: Bool) {
        DDLogVerbose("Start Scan Function")
        if centralManager.isScanning {
            DDLogVerbose("Central Manager is already scanning!!")
            return
        }
        let options: [String: Any] = [
            CBCentralManagerScanOptionAllowDuplicatesKey: NSNumber(booleanLiteral: true),
            CBCentralManagerOptionRestoreIdentifierKey: ManagerConstants.restoreIdentifier]
        filterUUID = [CBUUID]()
        filterUUID.append(mainService)
        let serviceUUIDs:[CBUUID] = filterUUID
        if centralManager == nil {
            DDLogVerbose("Central Manager intializing from func scan..")
            centralManager = CBCentralManager(delegate: self, queue: dispatchQueue, options: options)
        }
        //centralManager.scanForPeripherals(withServices: nil, options: options)
        DDLogVerbose("Scan for peripheral Called")
        // Scan Secure DFU Sensors and Normal SeekIt Sensors.
        centralManager.scanForPeripherals(withServices: [secureDFUUUID, seekitSensorsUUID], options: options)
        DDLogVerbose("SensorManager: Scanning for Services")
        if let previouslyConnectedSensors = lastConnectedSensors, previouslyConnectedSensors.count > 0 {
            for peripheral in centralManager.retrieveConnectedPeripherals(withServices: serviceUUIDs) {
                guard let peripheralUUID = UserDefaults.standard.string(forKey: peripheral.identifier.uuidString) else {
                    return
                }
                if let trackerDevice = sensorForPeripheral(peripheral, create: true, trackerID: peripheralUUID) {
                    trackerDevice.basePeripheral.delegate = trackerDevice.serviceModelManager
                    self.connectToSensor(trackerDevice)
                }
            }
            lastConnectedSensors = []
        }
    }
    
    @objc func rssiUpateTimerHandler(_ timer: Timer) {
        DDLogVerbose("Rssiupdate handler called")
        let now = Date.timeIntervalSinceReferenceDate
        for sensor in foundDevices {
            if now - sensor.lastSensorActivity > SLSensorManager.InactiveInterval {
                sensor.rssi = Int.min
            }
        }
    }
    
    func updateTrackerInfo(sensor: TASensor) {
        // Updates Found status to Panasonic Server
        var updateDict: [String: Any] = [:]
        updateDict["UUID"] = sensor.UUID
        updateDict["mode"] = 3
        SLCloudConnector.sharedInstance.setLostMode(lostModeDict: updateDict, success: { (successDict) in
            DispatchQueue.main.async {
                sensor.lostMode = 3
                DDLogVerbose("Tracker Status -> \(String(describing: sensor.trackerName!)) Marked As Found Updated Successfully")
                if let userID = UserDefaults.standard.string(forKey: AppConstants.userIDKey), let deviceRecord = SLRealmManager.sharedInstance.readDeviceRecords().filter({ $0.deviceId == "\(sensor.UUID!)\(userID)" }).first {
                    try! SLRealmManager.sharedInstance.realm.write {
                        deviceRecord.lostMode.value = 3 // 3 means found
                    }
                }
                NotificationCenter.default.post(
                    name: Notification.Name(rawValue: "notificationBellIcon"), object: nil, userInfo: nil)
                SLNotificationsManager.sharedInstance.scheduleLocalNotification(message:"\(sensor.trackerName!) was found nearby", body: "\(sensor.trackerName!) found")
            }
        }) { (errorDict) in
            DispatchQueue.main.async {
                DDLogVerbose("Tracker Status -> \(String(describing: sensor.trackerName!)) Mark As Found - FAILED !!!! -> \(String(describing: errorDict?.localizedDescription))")
            }
        }
    }
    
    fileprivate func sensorForPeripheral(_ peripheral: CBPeripheral, create: Bool, trackerID: String, advertisements: [CBUUID] = [], dfuFailed: Bool = false) -> TrackerDevice? {
        if dfuFailed {
            if let sensor = dfuSensorsId[peripheral.identifier.uuidString] {
                return sensor
            }
            if !create {
                return nil
            }
            let sensor = SensorType.init(peripheral: peripheral, trackerID: trackerID, advertisements: advertisements)
            //sensor.serviceFactory = serviceFactory
            dfuSensorsId[peripheral.identifier.uuidString] = sensor
            //SensorManager.logSensorMessage?("SensorManager: Created Sensor for Peripheral: \(peripheral)")
            return sensor
        } else {
            if let sensor = sensorsById[peripheral.identifier.uuidString] {
                return sensor
            }
            if !create {
                return nil
            }
            let sensor = SensorType.init(peripheral: peripheral, trackerID: trackerID, advertisements: advertisements)
            //sensor.serviceFactory = serviceFactory
            sensorsById[peripheral.identifier.uuidString] = sensor
            onSensorDiscovered => sensor
            //SensorManager.logSensorMessage?("SensorManager: Created Sensor for Peripheral: \(peripheral)")
            return sensor
        }
    }
    
    fileprivate func timerForDisconnect(_ sensor: TrackerDevice, _  error: Error?, create: Bool, delay: TimeInterval = TimeInterval(0)) -> Timer? {
        if let timer = disconnectTimerById[sensor.seekitUUID] {
            return timer
        }
        if !create {
            return nil
        }
        DDLogVerbose("timerForDisconnect tracker -> \(String(describing: sensor.deviceNickName)) timer \(delay)")
        let timer =  Timer.scheduledTimer(withTimeInterval: delay, repeats: false, block: { _ in
            self.disconnectNotification(sensor, error) /// came here
        })
        disconnectTimerById[sensor.seekitUUID] = timer
        return timer
    }
}

extension SLSensorManager: CBCentralManagerDelegate {
    
    /// :nodoc:
    public func centralManager(_ manager: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard error == nil else {
            DDLogVerbose("[Callback] Central Manager did fail to connect to peripheral \(String(describing: error?.localizedDescription))")
            return
        }
        SLSensorManager.logSensorMessage?("CBCentralManager: didFailToConnectPeripheral: \(peripheral)")
        
        guard let peripheralUUID = UserDefaults.standard.string(forKey: peripheral.identifier.uuidString) else {
            return
        }
        if let sensor = sensorForPeripheral(peripheral, create: false, trackerID: peripheralUUID) {
            onSensorConnectionFailed => sensor
        }
    }
    
    /// :nodoc:
    public func centralManager(_ manager: CBCentralManager, didConnect peripheral: CBPeripheral) {
        SLSensorManager.logSensorMessage?("CBCentralManager: didConnectPeripheral: \(peripheral)")
        guard let peripheralUUID = UserDefaults.standard.string(forKey: peripheral.identifier.uuidString) else {
            return
            
        }
        if let sensor = sensorForPeripheral(peripheral, create: true, trackerID: peripheralUUID) {
            //peripheral.discoverServices(serviceFactory.serviceUUIDs)
            print("Peripheral name \(String(describing: peripheral.name))and state \(peripheral.state)")
            if let timer = timerForDisconnect(sensor, nil, create: false) {
                timer.invalidate()
                disconnectTimerById[sensor.seekitUUID] = nil
            }
            if let tracker = self.foundDevices.filter({ return String($0.seekitUUID) ==  peripheralUUID}).first {
                tracker.serviceModelManager.discoverRegisteredServices()
                var fdsDict: [String: Any] = [:]
                fdsDict["UUID"] = String(sensor.seekitUUID)
                
            }
            sensor.subsrcibeState(foundDevices)
            onSensorConnected => sensor
            sensor.updateSensorInfo()
            
        }
    }
    
    /// :nodoc:
    public func centralManager(_ manager: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DDLogVerbose("[Callback] Central Manager did disconnect peripheral \(String(describing: error?.localizedDescription))")
        SLSensorManager.logSensorMessage?("CBCentralManager: didDisconnectPeripheral: \(peripheral)")
        guard let peripheralUUID = UserDefaults.standard.string(forKey: peripheral.identifier.uuidString) else {
            return
        }
        
        // Update Location for Disconnected Sensor.
        SLSensorManager.sharedInstance.updateLocalSensorLocation(trackerID: peripheralUUID, latitude: locationManager.latitude, longitude: locationManager.longitude)
        
        if let sensor = sensorForPeripheral(peripheral, create: false, trackerID: peripheralUUID), let device = SLCloudConnector.sharedInstance.devicesList?.sensorArray?.filter( { $0.UUID == peripheralUUID}).first {
            if device.sharedState == true, let currentUserID = UserDefaults.standard.string(forKey: AppConstants.userIDKey), let sharedUserID = device.sharedUserId, sharedUserID != "-1", sharedUserID != "", currentUserID != sharedUserID  {
                DispatchQueue.main.async(execute: {
                    self.disconnectNotification(sensor, error)
                })
            } else if isPickPocketModeActivated() == true {
                DispatchQueue.main.async(execute: {
                    self.disconnectNotification(sensor, error)
                })
            } else {
                var bufferInDisconnect = TimeInterval(0)
                if let version = device.deviceFirmwareVersion?.split(separator: "."), self.versionCheck(version: version) {
                    bufferInDisconnect = TimeInterval(90)
                    DDLogVerbose("\(String(describing: device.trackerName)) disconnect buffer: \(bufferInDisconnect)")
                }
                DispatchQueue.main.async(execute: {
                    let _ = self.timerForDisconnect(sensor, error, create: true, delay: bufferInDisconnect)
                })
            }
        }
    }
    
    func versionCheck(version: [Substring]) -> Bool {
        if version.count >= self.disconnectBufferFirmwareVersion.count {
            for i in 0..<self.disconnectBufferFirmwareVersion.count {
                if Int(version[i]) ?? 0 > self.disconnectBufferFirmwareVersion[i] {
                    return true
                } else if Int(version[i]) ?? 0 < self.disconnectBufferFirmwareVersion[i] {
                    return false
                } else if i == self.disconnectBufferFirmwareVersion.count - 1 {
                    return true
                }
            }
        }
        return false
    }
    
    @objc func disconnectNotification(_ sensor: TrackerDevice, _ error: Error?, _ notify: Bool = true){
        DDLogVerbose("disconnectNotification for \(sensor.deviceNickName)")
        let peripheralUUID = sensor.seekitUUID
        self.disconnectTimerById[peripheralUUID] = nil
        SLCloudConnector.sharedInstance.devicesList?.sensorArray?.filter( { $0.UUID == peripheralUUID}).forEach({ (device) in
            if sensor.basePeripheral.state == .connected {
                DDLogVerbose("sensor state connected for \(sensor.deviceNickName)")
                return
            }
            DDLogVerbose("sensor state disconnected for \(sensor.deviceNickName)")
            SLSensorManager.sharedInstance.updateSensorLocation(trackerID: peripheralUUID)
            // This will timeout connection for disconnected sensor.
            centralManager.cancelPeripheralConnection(sensor.basePeripheral)
            device.connectionStatus = "disconnected"
            sensor.disconnect()
            onSensorDisconnected => (sensor, error as NSError?)
            let name = String(describing: device.trackerName!.trimWhiteSpace())
            if ((!isSleepModeActivated() && !isWifiModeActivated()) || isPickPocketModeActivated()) && notify {
                SLNotificationsManager.sharedInstance.scheduleDisconnectNotification(message: "\(name) has been disconnected. Please mark lost to get notification from server", body: "", trackerID: peripheralUUID, alertMode: device.alertMode!, ringUrl: device.customRingtoneURL ?? "", ringName: device.ringToneName ?? "")
            }
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name(rawValue: ManagerConstants.refreshStatusKey), object: nil, userInfo: nil)
            }
            removeOutOfRangeSensor(sensor: sensor)
        })
        if /*error == nil && */sensor.basePeripheral.state != .connected{
            sensorsById.removeValue(forKey: sensor.basePeripheral.identifier.uuidString)
            onSensorRemoved => sensor
        }
    }
    
    /// :nodoc:
    public func centralManager(_ manager: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        //debugPrint(advertisementData)
        //debugPrint("Sensor Name:- \(String(describing: peripheral.name))")
        if let serviceUUIDArr = advertisementData["kCBAdvDataServiceUUIDs"] as? NSArray, let serviceID = serviceUUIDArr.firstObject, "\(serviceID)" == secureDFUUUID.uuidString {
            // We only Get Sensors here that are stuck in DFU Service.
            let serviceUUID:[CBUUID] = [self.secureDFUUUID]
            guard let deviceName = peripheral.name else {
                return
            }
            if var sensor = self.sensorForPeripheral(peripheral, create: true, trackerID: deviceName, advertisements: serviceUUID, dfuFailed: true) {
                if ((self.dfuFailedDevices.contains(sensor)) == false) {
                    sensor.deviceNickName = "\(deviceName)"
                    sensor.timeStamp = Date.init()
                } else {
                    if let index = self.dfuFailedDevices.index(of: sensor) {
                        sensor = self.dfuFailedDevices[index]
                        sensor.rssi = RSSI.intValue
                        sensor.deviceNickName = "\(deviceName)"
                        sensor.timeStamp = Date.init()
                    }
                }
                sensor.markSensorActivity()
            }
        } else {
            
            guard let _ = peripheral.name, let sensorLocalName = advertisementData["kCBAdvDataLocalName"], let advServiceUUID = advertisementData["kCBAdvDataServiceUUIDs"] as? NSArray, let advertisementDataDict = advertisementData["kCBAdvDataServiceData"] as? NSDictionary, let serviceID = advServiceUUID.firstObject, let serviceData = advertisementDataDict.allValues[0] as? Data, serviceData.hexString.count == 18, let fdsServiceData = advertisementDataDict.allKeys as? NSArray, let fdsKey = fdsServiceData.firstObject else {
                return
            }
            
            //        print("FDSLog:- FDS Detector Key Name:- \(fdsKey)")
            //        print("FDSLog:- Service UUID:- \(serviceID)")
            
            DispatchQueue.main.async(execute: {
                let trackerID = "0x\(serviceData.hexString.uppercased())"
                print(trackerID.count)
                DDLogVerbose("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
                DDLogVerbose("SensorName: \(sensorLocalName) | SensorID: \(trackerID) | RSSI:- \(RSSI) ")
                DDLogVerbose("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
                if "\(sensorLocalName)".count == 0 {
                    DDLogVerbose("Ignoring blank local name: \(sensorLocalName) having, SensorID: \(trackerID) | RSSI:- \(RSSI) ")
                    return
                }
                UserDefaults.standard.setValue(String(trackerID.prefix(18)), forKey: peripheral.identifier.uuidString)
                UserDefaults.standard.synchronize()
                let serviceUUID:[CBUUID] = [self.seekitSensorsUUID]
                if var sensor = self.sensorForPeripheral(peripheral, create: true, trackerID: trackerID, advertisements: serviceUUID) {
                    if ((self.foundDevices.contains(sensor)) == false) {
                        sensor.deviceNickName = "\(sensorLocalName)"
                        sensor.timeStamp = Date.init()
                    } else {
                        if let index = self.foundDevices.index(of: sensor) {
                            sensor = self.foundDevices[index]
                            sensor.rssi = RSSI.intValue
                            sensor.deviceNickName = "\(sensorLocalName)"
                            sensor.timeStamp = Date.init()
                        }
                    }
                    if "\(fdsKey)".uppercased() == "DEAD" {
                        print("FDSLog:- FDS Detector Key Name:- \(fdsKey)")
                        print("FDSLog:- Service UUID:- \(serviceID)")
                        print("FDSLog:- FDS Error Device Detected. Take Necessary Action => ")
                        if ((self.fdsDevices.contains(sensor)) == false) {
                            print("FDSLog:- Appending to FDS List ")
                            self.fdsDevices.append(sensor)
                        }
                    }
                    sensor.markSensorActivity()
                }
            })
        }
    }
    
    func convertToDictionary(text: String) -> [String: Any]? {
        if let data = text.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            } catch {
                DDLogVerbose("Convert to dictionary error => \(error.localizedDescription)")
            }
        }
        return nil
    }
    
    func resetSensorAfterDisconnection(){
        
        if let sensorArray = SLCloudConnector.sharedInstance.devicesList?.sensorArray {
            sensorArray.forEach({ sensorDevice in
                for foundDevice in foundDevices {
                    foundDevice.stopTimer()
                    foundDevice.serviceModelManager.notifyHandler = nil
                }
            })
        }
    }
    
    /// :nodoc:
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        SLSensorManager.logSensorMessage?("centralManagerDidUpdateState: \(central.state.rawValue)")
        
        if #available(iOS 10.0, *) {
            switch central.state{
                
            case .unknown:
                DDLogVerbose("centralManagerDidUpdateState: Unknown")
            case .resetting:
                DDLogVerbose("centralManagerDidUpdateState: resetting")
            case .unsupported:
                DDLogVerbose("centralManagerDidUpdateState: unsupported")
            case .unauthorized:
                print("This app is not authorised to use Bluetooth low energy")
            case .poweredOff:
                SLCloudConnector.sharedInstance.devicesList?.sensorArray?.filter({ $0.type != 3 }).forEach({ (device) in
                    if let connectedDevice = self.foundDevices.filter( { String($0.trackerUUID.prefix(18)) == device.UUID}).first {
                        disconnectNotification(connectedDevice, nil, false)
                    } else {
                        device.connectionStatus = "disconnected"
                    }
                })
                SLNotificationsManager.sharedInstance.BluetoothOff(message: "Bluetooth is turned off, App will be unable to connect to your device(s)", body: "", type: 1)
                print("Bluetooth is currently powered off.")
                self.delegate?.manager(self, powerState: false)
                SLSensorManager.sharedInstance.stopAutoConnectTimer()
                NotificationCenter.default.post(
                    name: Notification.Name(rawValue: AppConstants.bluetoothPowerOffNotification), object: nil, userInfo: nil)
                resetSensorAfterDisconnection()
                stopScan()
                
            case .poweredOn:
                print("Bluetooth is currently powered on and available to use.")
                DDLogVerbose("centralManagerDidUpdateState: poweredOn")
                SLSensorManager.sharedInstance.startAutoConnectTimer()
                if let lastPendingSensors = lastConnectedSensors, lastPendingSensors.count > 0  {
                    
                }
                //                DispatchQueue.main.asyncAfter(deadline: .now() + timerScanInterval) {
                //                    self.pauseScan()
                //                }
                // Initiate Scan for Peripherals
                stateUpdated()
                self.delegate?.manager(self, powerState: true)
                NotificationCenter.default.post(
                    name: Notification.Name(rawValue: AppConstants.bluetoothPoweredOnNotification), object: nil, userInfo: nil)
                onBluetoothStateChange => CBManagerState(rawValue: central.state.rawValue)!
                startScan()
            default:break
            }
        } else {
            // Fallback on earlier versions
            switch central.state.rawValue {
            case 3: // CBCentralManagerState.unauthorized :
                print("This app is not authorised to use Bluetooth low energy")
            case 4: // CBCentralManagerState.poweredOff:
                self.foundDevices.filter {($0.basePeripheral.state == .disconnected )}.forEach {
                    connectedDevice in
                    disconnectNotification(connectedDevice, nil, false)
                }
                SLNotificationsManager.sharedInstance.BluetoothOff(message: "Bluetooth is turned off, App will be unable to connect to your device(s)", body: "", type: 1)
                print("Bluetooth is currently powered off.")
                NotificationCenter.default.post(
                    name: Notification.Name(rawValue: AppConstants.bluetoothPowerOffNotification), object: nil, userInfo: nil)
                resetSensorAfterDisconnection()
                stopScan()
            case 5: //CBCentralManagerState.poweredOn:
                print("Bluetooth is currently powered on and available to use.")
                DDLogVerbose("centralManagerDidUpdateState: poweredOn")
                if let lastPendingSensors = lastConnectedSensors, lastPendingSensors.count > 0  {
                    
                }
                //                DispatchQueue.main.asyncAfter(deadline: .now() + timerScanInterval) {
                //                    self.pauseScan()
                //                }
                // Initiate Scan for Peripherals
                stateUpdated()
                self.delegate?.manager(self, powerState: true)
                NotificationCenter.default.post(
                    name: Notification.Name(rawValue: AppConstants.bluetoothPoweredOnNotification), object: nil, userInfo: nil)
                onBluetoothStateChange => CBManagerState(rawValue: central.state.rawValue)!
                startScan()
            default:break
            }
        }
    }
}
