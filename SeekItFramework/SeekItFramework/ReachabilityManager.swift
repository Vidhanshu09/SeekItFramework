//
//  ReachabilityManager.swift
//  PanasonicTracker
//
//  Created by Chamoli, Jitendra on 25/01/18.
//  Copyright © 2018 Chamoli, Jitendra. All rights reserved.
//

import Foundation
import ReachabilitySwift
import CocoaLumberjack
import CoreBluetooth

/// Protocol for listenig network status change
public protocol NetworkStatusListener : class {
    func networkStatusDidChange(status: Reachability.NetworkStatus)
}

public class ReachabilityManager: NSObject {
    public static  let shared = ReachabilityManager()  // 2. Shared instance
    var count:Int = 0
    //private init() {}
    
    public var isNetworkAvailable : Bool {
        return reachabilityStatus != .none
    }
    public var reachabilityStatus: Reachability.NetworkStatus = .notReachable
    public let reachability = Reachability()!
    
    // 6. Array of delegates which are interested to listen to network status change
    var listeners = [NetworkStatusListener]()
    
    /// Called whenever there is a change in NetworkReachibility Status
    ///
    /// — parameter notification: Notification with the Reachability instance
    @objc func reachabilityChanged(notification: Notification) {
        let reachability = notification.object as! Reachability
        switch reachability.currentReachabilityStatus {
        case .notReachable:
            //debugPrint("Network became unreachable")
            SLSensorManager.sharedInstance.safeZoneAction()
            DDLogVerbose("Network became unreachable")
        //NotificationsManager.sharedInstance.scheduleLocalNotification(message: "Safe Zone Off - None", body: "High Alert Mode")
        case .reachableViaWiFi:
            //debugPrint("Network reachable through WiFi")
            count = count + 1
            DDLogVerbose("\(count) Network reachable through WiFi")
            let connectedWifiDict =  SSID.fetchSSIDInfo()
            if let currentConnectedWifi = connectedWifiDict["SSID"] as? String, let currentConnectedWifiBSSID = connectedWifiDict["BSSID"] as? String {
                
                if let wifiRecord =  SLRealmManager.sharedInstance.readWiFiRecords().filter({($0.wifiBSSID == currentConnectedWifiBSSID )}).first {
                    if wifiRecord.isEnabled {
                        SLSensorManager.sharedInstance.makeDevicesSleep()
                        //NotificationsManager.sharedInstance.scheduleLocalNotification(message: "Safe Zone On - WIFI", body: "Low Alert Mode")
                    } else {
                        if !SLSensorManager.sharedInstance.isSleepModeActivated() {
                            SLSensorManager.sharedInstance.restoreSleepDevices()
                        }
                        //NotificationsManager.sharedInstance.scheduleLocalNotification(message: "Safe Zone Off - WIFI", body: "High Alert Mode")
                    }
                } else {
                    // New WiFi Record
                    let wifiRecord = WifiInfo()
                    wifiRecord.wifiSSID = currentConnectedWifi
                    wifiRecord.wifiBSSID = currentConnectedWifiBSSID
                    wifiRecord.isEnabled = false
                    DispatchQueue.main.async {
                        SLRealmManager.sharedInstance.writeWifiRecord(wifi: wifiRecord)
                    }
                }
            }
        case .reachableViaWWAN:
            DDLogVerbose("Network reachable through Cellular Data")
            SLSensorManager.sharedInstance.safeZoneAction()
            //NotificationsManager.sharedInstance.scheduleLocalNotification(message: "Safe Zone Off - CELLULAR", body: "High Alert Mode")
        }
        
        // Sending message to each of the delegates
        for listener in listeners {
            listener.networkStatusDidChange(status: reachability.currentReachabilityStatus)
        }
    }
    
    
    /// Starts monitoring the network availability status
    public func startMonitoring() {
        
        stopMonitoring()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.reachabilityChanged),
                                               name: ReachabilityChangedNotification,
                                               object: reachability)
        do{
            try reachability.startNotifier()
        }catch{
            //debugPrint("Could not start reachability notifier")
            DDLogVerbose("Could not start reachability notifier")
        }
    }
    
    /// Stops monitoring the network availability status
    public func stopMonitoring() {
        reachability.stopNotifier()
        NotificationCenter.default.removeObserver(self, name: ReachabilityChangedNotification,
                                                  object: reachability)
    }
    
    /// Adds a new listener to the listeners array
    ///
    /// - parameter delegate: a new listener
    public func addListener(listener: NetworkStatusListener){
        listeners.append(listener)
    }
    
    /// Removes a listener from listeners array
    ///
    /// - parameter delegate: the listener which is to be removed
    public func removeListener(listener: NetworkStatusListener){
        listeners = listeners.filter{ $0 !== listener}
    }
}
