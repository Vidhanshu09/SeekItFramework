//
//  NotificationsManager.swift
//  SeekLib
//
//  Created by Jitendra Chamoli on 09/10/18.
//

import Foundation
import UIKit
import SwiftyJSON
import CocoaLumberjack
import UserNotifications

/**
 Notifications Manager to manage local and Remote Notifications
 */

public class SLNotificationsManager: NSObject {
    
    fileprivate let audioPlayer = SLAudioPlayer.sharedInstance
    fileprivate let gcmMessageIDKey = "gcm.message_id"
    
    /**
     Shared instance for Notifications Manager
     */
    public static let sharedInstance = SLNotificationsManager()
    
    fileprivate override init() {
        super.init()
        setupLocalNotification()
    }
    
    fileprivate func setupLocalNotification() {
        
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().getNotificationSettings { (notificationSettings) in
                switch notificationSettings.authorizationStatus {
                case .notDetermined:
                    self.requestAuthorization(completionHandler: { (success) in
                        guard success else { return }
                        
                        // Schedule Local Notification
                    })
                case .authorized:
                    // Schedule Local Notification
                    DDLogVerbose("App is authorized to display local notifications")
                //self.scheduleLocalNotification(message: "Welcome to Panasonic Tracker", body: "App Info")
                case .denied:
                    DDLogVerbose("Application Not Allowed to Display Notifications")
                //self.showError(message: "Application Not Allowed to Display Notifications.")
                case .provisional:
                    DDLogVerbose("// The application is authorized to post non-interruptive user notifications.")
                }
            }
        } else {
            // Fallback on earlier versions
        }
    }
    
    private func requestAuthorization(completionHandler: @escaping (_ success: Bool) -> ()) {
        // Request Authorization
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { (success, error) in
                if let error = error {
                    DDLogVerbose("Request Notifications Authorization Failed (\(error), \(error.localizedDescription))")
                }
                
                completionHandler(success)
            }
        } else {
            // Fallback on earlier versions
        }
    }
    
    func showBackgroundNotification(message aMessage : String){
        let localNotification = UILocalNotification()
        localNotification.alertAction   = "Show"
        localNotification.alertBody     = aMessage
        localNotification.hasAction     = false
        localNotification.fireDate      = Date(timeIntervalSinceNow: 1)
        localNotification.timeZone      = TimeZone.current
        localNotification.soundName     = UILocalNotificationDefaultSoundName
    }
    
    public func scheduleLocalNotification(message aMessage : String, body abody : String) {
        // Create Notification Content
        if #available(iOS 10.0, *) {
            let notificationContent = UNMutableNotificationContent()
            // Configure Notification Content
            notificationContent.title = AppConstants.notificationAlertTitle
            notificationContent.subtitle = abody
            notificationContent.body = aMessage
            notificationContent.userInfo = ["isLocal" : true]
            
            // Add Trigger
            let notificationTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
            
            // Create Notification Request
            let uuid = UUID().uuidString // Unique ID to each fired location Notification
            let notificationRequest = UNNotificationRequest(identifier: "com.omni.panasonic.localNotification\(uuid)", content: notificationContent, trigger: notificationTrigger)
            
            // Add Request to User Notification Center
            UNUserNotificationCenter.current().add(notificationRequest) { (error) in
                if let error = error {
                    debugPrint("Unable to Add Notification Request (\(error), \(error.localizedDescription))")
                } else {
                    // Save this information in DB
                    let date = Date()
                    let newN:NotifyHistoryInfo = NotifyHistoryInfo()
                    newN.notifyId = uuid
                    newN.notifyDate = date
                    newN.notifyMessage = aMessage
                    DispatchQueue.main.async {
                        SLRealmManager.sharedInstance.writeNotifyRecord(notify: newN)
                    }
                }
            }
        } else {
            // Fallback on earlier versions
            // ios 9
            let notification = UILocalNotification()
            notification.fireDate = Date()
            notification.alertBody = aMessage //"Hey you! Yeah you! Swipe to unlock!"
            notification.alertTitle = AppConstants.notificationAlertTitle
            //notification.alertAction = "be awesome!"
            notification.soundName = UILocalNotificationDefaultSoundName
            // Save this information in DB
            let uuid = UUID().uuidString // Unique ID to each fired Notification
            // Save this information in DB
            let date = Date()
            let newN:NotifyHistoryInfo = NotifyHistoryInfo()
            newN.notifyId = uuid
            newN.notifyDate = date
            newN.notifyMessage = aMessage
            DispatchQueue.main.async {
                SLRealmManager.sharedInstance.writeNotifyRecord(notify: newN)
            }
            UIApplication.shared.scheduleLocalNotification(notification)
        }
    }
    
    public func scheduleDisconnectNotification(message aMessage : String, body abody : String, trackerID: String, alertMode: NSNumber, ringUrl:String, ringName: String) {
        // Create Notification Content
        let userLoginStatus = UserDefaults.standard.bool(forKey: AppConstants.isUserLoggedInKey)
        if !userLoginStatus{
            DDLogVerbose("Prevented disconnect notification after logout")
            return
        }
        if SLSensorManager.sharedInstance.updatingDFUDevice {
            DDLogVerbose("Prevented disconnect notification while DFU Update is in progress")
            return
        }
        if let device = SLCloudConnector.sharedInstance.devicesList?.sensorArray?.filter({ $0.UUID == trackerID }) {
            if device.count == 0 || (device.first?.autoConnect)! == false {
                DDLogVerbose("Prevented disconnect notification for deleted or manually disconnected device")
                return
            }
            //(device.first?.sharedState)! ||
            if let currentUserID = UserDefaults.standard.string(forKey: AppConstants.userIDKey), let sharedUserID = (device.first?.sharedUserId) {
                if sharedUserID != currentUserID && SLSensorManager.sharedInstance.bluetoothEnabled && SLSensorManager.sharedInstance.centralManager.state == .poweredOn && sharedUserID != "-1" {
                    // Disable Alert if Device is shared and accepted
                    DDLogVerbose("Prevented disconnect notification for shared Tracker device in Primary User")
                    return
                } else if sharedUserID == currentUserID && SLSensorManager.sharedInstance.bluetoothEnabled && SLSensorManager.sharedInstance.centralManager.state == .poweredOn {
                    DDLogVerbose("Allowed disconnect notification for shared Tracker device in Secondary User")
                    // Device Disconnected from Secondary User
                    // Continue showing alert for Disconnection
                }
            }
        }
        
        // Return if FDS Eror
        SLSensorManager.sharedInstance.fdsDevices.forEach { sensor in
            if String(sensor.trackerUUID.prefix(18)) == trackerID {
                return
            }
        }
        // ** TO CHECK SLEEP MODE AND WIFI MODE SETTINGS ** //
        let sleepModeActive = SLSensorManager.sharedInstance.isSleepModeActivated()
        let wifiModeActive = SLSensorManager.sharedInstance.isWifiModeActivated()
        
        // Separation Ringtone alert for Disconnected Sensor
        if SLSensorManager.sharedInstance.bluetoothEnabled &&
            !(sleepModeActive || wifiModeActive) && !SLSensorManager.sharedInstance.updatingDFUDevice {
            // ** DO NOT BUZZ SEPARATION MODE RING WHEN SLEEP MODE OR WIFI MODE IS ACTIVE ** //
            DispatchQueue.main.async {
                if alertMode == AppConstants.HIGH_ALERT_MODE {
                    SLAudioPlayer.sharedInstance.playLoopingSound(alertMode: alertMode, buzzType: "normal", ringURL: ringUrl, ringName: ringName)
                } else {
                    SLAudioPlayer.sharedInstance.playLoopingSound(alertMode: alertMode, buzzType: "disconnected", ringURL: ringUrl, ringName: ringName)
                }
            }
            if alertMode == AppConstants.HIGH_ALERT_MODE {
                DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) {
                    SLAudioPlayer.sharedInstance.stopSound()
                }
            }
        }
        // Update Location for Disconnected Sensor.
        SLSensorManager.sharedInstance.updateSensorLocation(trackerID: trackerID)
        
        if let userID = UserDefaults.standard.string(forKey: AppConstants.userIDKey) {
            DDLogVerbose("Writing Tracker Auto Disconnect Event for Device UUID \(trackerID) userID \(userID)")
            let newLog = TrackerLog()
            newLog.eventId = UUID().uuidString
            newLog.eventDate = Date()
            newLog.trackerUUID = trackerID
            //newLog.eventType = EventType.autoDisconnet.rawValue
            DispatchQueue.main.async {
                SLRealmManager.sharedInstance.writeLog(logInfo: newLog)
            }
        }
        // Separation Ringtone alert for Disconnected Sensor
        //        if SensorManager.sharedInstance.bluetoothEnabled && SensorManager.sharedInstance.centralManager.state == .poweredOn {
        //            DispatchQueue.main.async {
        //                TAAudioPlayer.sharedInstance.playLoopingSound(alertMode: 3)
        //            }
        //            DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) {
        //                TAAudioPlayer.sharedInstance.stopSound()
        //            }
        //        }
        
        DispatchQueue.main.async {
            if UIApplication.shared.applicationState == .background {
                DDLogVerbose("Prevented disconnect notification while the app is in background")
            }
            return
        }
        var infoDict:[String:Any] = [:]
        infoDict["UUID"] = trackerID
        infoDict["alertMode"] = alertMode
        
        if #available(iOS 10.0, *) {
            let notificationContent = UNMutableNotificationContent()
            // Configure Notification Content
            notificationContent.title = AppConstants.notificationAlertTitle
            notificationContent.subtitle = abody
            notificationContent.body = aMessage
            notificationContent.userInfo = infoDict
            notificationContent.categoryIdentifier = AppConstants.disconnectCategoryIdentifer
            // Add Trigger
            let notificationTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
            
            // Create Notification Request
            let uuid = UUID().uuidString // Unique ID to each fired location Notification
            let notificationRequest = UNNotificationRequest(identifier: "com.omni.panasonic.disconnectNotification", content: notificationContent, trigger: notificationTrigger)
            
            // Add Request to User Notification Center
            UNUserNotificationCenter.current().add(notificationRequest) { (error) in
                if let error = error {
                    debugPrint("Unable to Add Notification Request (\(error), \(error.localizedDescription))")
                } else {
                    // Save this information in DB
                    let date = Date()
                    let newN:NotifyHistoryInfo = NotifyHistoryInfo()
                    newN.notifyId = uuid
                    newN.notifyDate = date
                    newN.readStatus = "pending"
                    newN.notifyMessage = aMessage
                    DispatchQueue.main.async {
                        SLRealmManager.sharedInstance.writeNotifyRecord(notify: newN)
                        self.fireUnreadNotify()
                    }
                }
            }
            // Notification Action
            /*let markAsLostAction = UNNotificationAction(identifier: AppConstants.markAsLostActionIdentifer, title: AppConstants.markAsLostActionTitle, options: [])
             let category = UNNotificationCategory(identifier: AppConstants.disconnectCategoryIdentifer, actions: [markAsLostAction], intentIdentifiers: [], options: [])
             UNUserNotificationCenter.current().setNotificationCategories([category])
             DispatchQueue.main.async {
             UNUserNotificationCenter.current().delegate = AppDelegate.shared
             Messaging.messaging().delegate = AppDelegate.shared
             }*/
        } else {
            // Fallback on earlier versions
            // ios 9
            DispatchQueue.main.async {
                if UIApplication.shared.applicationState == .active {
                    let notification = UILocalNotification()
                    notification.fireDate = Date()
                    notification.alertTitle = AppConstants.notificationAlertTitle
                    notification.alertBody = aMessage
                    notification.userInfo = infoDict
                    notification.category = AppConstants.disconnectCategoryIdentifer
                    notification.soundName = UILocalNotificationDefaultSoundName
                    
                    let markAsLostAction = UIMutableUserNotificationAction()
                    markAsLostAction.identifier = AppConstants.markAsLostActionIdentifer
                    markAsLostAction.title = AppConstants.markAsLostActionTitle
                    markAsLostAction.isDestructive = false
                    markAsLostAction.isAuthenticationRequired = false
                    markAsLostAction.activationMode = .background
                    
                    let category = UIMutableUserNotificationCategory()
                    category.identifier = AppConstants.disconnectCategoryIdentifer // Identifier passed in the payload
                    category.setActions([markAsLostAction], for: .default)
                    // Save this information in DB
                    let uuid = UUID().uuidString // Unique ID to each fired Notification
                    // Save this information in DB
                    let date = Date()
                    let newN:NotifyHistoryInfo = NotifyHistoryInfo()
                    newN.notifyId = uuid
                    newN.readStatus = "pending"
                    newN.notifyDate = date
                    newN.notifyMessage = aMessage
                    SLRealmManager.sharedInstance.writeNotifyRecord(notify: newN)
                    self.fireUnreadNotify()
                    UIApplication.shared.scheduleLocalNotification(notification)
                }
            }
        }
    }
    
    // MARK:- Activate Sleep Time Notification
    
    public func DNDActivateSleepTime(message aMessage : String, body abody : String, type: NSNumber) {
        NotificationCenter.default.post(
            name: Notification.Name(rawValue: "notificationBellIcon"), object: nil, userInfo: nil)
        // Create Notification Content
        if #available(iOS 10.0, *) {
            let notificationContent = UNMutableNotificationContent()
            // Configure Notification Content
            notificationContent.title = AppConstants.notificationAlertTitle
            //notificationContent.subtitle = abody
            notificationContent.body = aMessage
            //notificationContent.userInfo = infoDict
            
            let notificationTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
            
            // Create Notification Request
            let uuid = UUID().uuidString // Unique ID to each fired location Notification
            let notificationRequest = UNNotificationRequest(identifier: "com.omni.panasonic.activateDND", content: notificationContent, trigger: notificationTrigger)
            
            // Add Request to User Notification Center
            UNUserNotificationCenter.current().add(notificationRequest) { (error) in
                if let error = error {
                    debugPrint("Unable to Add Notification Request (\(error), \(error.localizedDescription))")
                } else {
                    // Save this information in DB
                    let date = Date()
                    let newN:NotifyHistoryInfo = NotifyHistoryInfo()
                    newN.notifyId = uuid
                    newN.notifyDate = date
                    newN.readStatus = "pending"
                    newN.notifyTitle = "Activate Sleep Time"
                    newN.notifyMessage = aMessage
                    DispatchQueue.main.async {
                        SLRealmManager.sharedInstance.writeNotifyRecord(notify: newN)
                        self.fireUnreadNotify()
                    }
                }
            }
            
        } else {
            // Fallback on earlier versions
            // ios 9
            DispatchQueue.main.async {
                if UIApplication.shared.applicationState == .active || UIApplication.shared.applicationState == .inactive || UIApplication.shared.applicationState == .background {
                    let notification = UILocalNotification()
                    notification.fireDate = Date()
                    notification.alertTitle = AppConstants.notificationAlertTitle
                    notification.alertBody = aMessage //"Hey you! Yeah you! Swipe to unlock!"
                    
                    // Save this information in DB
                    let uuid = UUID().uuidString // Unique ID to each fired Notification
                    // Save this information in DB
                    let date = Date()
                    let newN:NotifyHistoryInfo = NotifyHistoryInfo()
                    newN.notifyId = uuid
                    newN.notifyDate = date
                    newN.sharingStatus = "done"
                    newN.readStatus = "pending"
                    newN.notifyTitle = "Activate Sleep Time"
                    newN.notifyMessage = aMessage
                    SLRealmManager.sharedInstance.writeNotifyRecord(notify: newN)
                    self.fireUnreadNotify()
                    UIApplication.shared.scheduleLocalNotification(notification)
                }
            }
        }
    }
    
    public func scheduleSessionExpiredNotification(message aMessage : String, body abody : String) {
        // Create Notification Content
        if #available(iOS 10.0, *) {
            let notificationContent = UNMutableNotificationContent()
            // Configure Notification Content
            notificationContent.title = AppConstants.notificationAlertTitle
            notificationContent.subtitle = abody
            notificationContent.body = aMessage
            notificationContent.categoryIdentifier = AppConstants.sessionExpiredCategoryIdenfier
            // Add Trigger
            let notificationTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
            
            // Create Notification Request
            let uuid = UUID().uuidString // Unique ID to each fired location Notification
            let notificationRequest = UNNotificationRequest(identifier: "com.omni.panasonic.sessionExpired", content: notificationContent, trigger: notificationTrigger)
            
            // Add Request to User Notification Center
            UNUserNotificationCenter.current().add(notificationRequest) { (error) in
                if let error = error {
                    debugPrint("Unable to Add Notification Request (\(error), \(error.localizedDescription))")
                } else {
                    // Save this information in DB
                    let date = Date()
                    let newN:NotifyHistoryInfo = NotifyHistoryInfo()
                    newN.notifyId = uuid
                    newN.notifyDate = date
                    newN.readStatus = "pending"
                    newN.notifyMessage = aMessage
                    DispatchQueue.main.async {
                        SLRealmManager.sharedInstance.writeNotifyRecord(notify: newN)
                    }
                }
            }
        } else {
            // Fallback on earlier versions
            // ios 9
            let notification = UILocalNotification()
            notification.fireDate = Date()
            notification.alertTitle = "PanasonicTracker"
            notification.alertBody = aMessage //"Hey you! Yeah you! Swipe to unlock!"
            //notification.alertAction = "be awesome!"
            notification.category = AppConstants.sessionExpiredCategoryIdenfier
            notification.soundName = UILocalNotificationDefaultSoundName
            // Save this information in DB
            let uuid = UUID().uuidString // Unique ID to each fired Notification
            // Save this information in DB
            let date = Date()
            let newN:NotifyHistoryInfo = NotifyHistoryInfo()
            newN.notifyId = uuid
            newN.notifyDate = date
            newN.notifyMessage = aMessage
            newN.readStatus = "pending"
            DispatchQueue.main.async {
                SLRealmManager.sharedInstance.writeNotifyRecord(notify: newN)
            }
            UIApplication.shared.scheduleLocalNotification(notification)
        }
        self.fireUnreadNotify()
    }
    
    public func scheduleLowBatteryNotification(message aMessage : String, body abody : String) {
        // Create Notification Content
        if #available(iOS 10.0, *) {
            let notificationContent = UNMutableNotificationContent()
            // Configure Notification Content
            notificationContent.title = AppConstants.notificationAlertTitle
            notificationContent.subtitle = abody
            notificationContent.body = aMessage
            notificationContent.categoryIdentifier = AppConstants.lowBatteryAlertCategoryIdenfier
            // Add Trigger
            let notificationTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
            
            // Create Notification Request
            let uuid = UUID().uuidString // Unique ID to each fired location Notification
            let notificationRequest = UNNotificationRequest(identifier: "com.omni.panasonic.lowBatteryAlert", content: notificationContent, trigger: notificationTrigger)
            
            // Add Request to User Notification Center
            UNUserNotificationCenter.current().add(notificationRequest) { (error) in
                if let error = error {
                    debugPrint("Unable to Add Notification Request (\(error), \(error.localizedDescription))")
                } else {
                    // Save this information in DB
                    let date = Date()
                    let newN:NotifyHistoryInfo = NotifyHistoryInfo()
                    newN.notifyId = uuid
                    newN.notifyDate = date
                    newN.readStatus = "pending"
                    newN.notifyMessage = aMessage
                    DispatchQueue.main.async {
                        SLRealmManager.sharedInstance.writeNotifyRecord(notify: newN)
                        self.fireUnreadNotify()
                    }
                }
            }
        } else {
            // Fallback on earlier versions
            // ios 9
            let notification = UILocalNotification()
            notification.fireDate = Date()
            notification.alertTitle = "PanasonicTracker"
            notification.alertBody = aMessage //"Hey you! Yeah you! Swipe to unlock!"
            //notification.alertAction = "be awesome!"
            notification.category = AppConstants.lowBatteryAlertCategoryIdenfier
            notification.soundName = UILocalNotificationDefaultSoundName
            // Save this information in DB
            let uuid = UUID().uuidString // Unique ID to each fired Notification
            // Save this information in DB
            let date = Date()
            let newN:NotifyHistoryInfo = NotifyHistoryInfo()
            newN.notifyId = uuid
            newN.notifyDate = date
            newN.notifyMessage = aMessage
            newN.readStatus = "pending"
            DispatchQueue.main.async {
                SLRealmManager.sharedInstance.writeNotifyRecord(notify: newN)
                self.fireUnreadNotify()
            }
            UIApplication.shared.scheduleLocalNotification(notification)
        }
    }
    
    public func GPSOff(message aMessage : String, body abody : String, type: NSNumber) {
        NotificationCenter.default.post(
            name: Notification.Name(rawValue: "notificationBellIcon"), object: nil, userInfo: nil)
        // Create Notification Content
        if #available(iOS 10.0, *) {
            let notificationContent = UNMutableNotificationContent()
            // Configure Notification Content
            notificationContent.title = AppConstants.notificationAlertTitle
            //notificationContent.subtitle = abody
            notificationContent.body = aMessage
            //notificationContent.userInfo = infoDict
            
            let notificationTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
            
            // Create Notification Request
            let uuid = UUID().uuidString // Unique ID to each fired location Notification
            let notificationRequest = UNNotificationRequest(identifier: "com.omni.panasonic.GPSOff", content: notificationContent, trigger: notificationTrigger)
            
            // Add Request to User Notification Center
            UNUserNotificationCenter.current().add(notificationRequest) { (error) in
                if let error = error {
                    debugPrint("Unable to Add Notification Request (\(error), \(error.localizedDescription))")
                } else {
                    // Save this information in DB
                    let date = Date()
                    let newN:NotifyHistoryInfo = NotifyHistoryInfo()
                    newN.notifyId = uuid
                    newN.notifyDate = date
                    newN.readStatus = "pending"
                    newN.notifyTitle = "GPS off"
                    newN.notifyMessage = aMessage
                    DispatchQueue.main.async {
                        SLRealmManager.sharedInstance.writeNotifyRecord(notify: newN)
                        self.fireUnreadNotify()
                    }
                }
            }
            
        } else {
            // Fallback on earlier versions
            // ios 9
            DispatchQueue.main.async {
                if UIApplication.shared.applicationState == .active || UIApplication.shared.applicationState == .inactive || UIApplication.shared.applicationState == .background {
                    let notification = UILocalNotification()
                    notification.fireDate = Date()
                    notification.alertTitle = AppConstants.notificationAlertTitle
                    notification.alertBody = aMessage //"Hey you! Yeah you! Swipe to unlock!"
                    
                    // Save this information in DB
                    let uuid = UUID().uuidString // Unique ID to each fired Notification
                    // Save this information in DB
                    let date = Date()
                    let newN:NotifyHistoryInfo = NotifyHistoryInfo()
                    newN.notifyId = uuid
                    newN.notifyDate = date
                    newN.sharingStatus = "done"
                    newN.readStatus = "pending"
                    newN.notifyTitle = "GPS off"
                    newN.notifyMessage = aMessage
                    SLRealmManager.sharedInstance.writeNotifyRecord(notify: newN)
                    self.fireUnreadNotify()
                    UIApplication.shared.scheduleLocalNotification(notification)
                }
            }
        }
    }
    
    public func BluetoothOff(message aMessage : String, body abody : String, type: NSNumber) {
        NotificationCenter.default.post(
            name: Notification.Name(rawValue: "notificationBellIcon"), object: nil, userInfo: nil)
        // Create Notification Content
        if #available(iOS 10.0, *) {
            let notificationContent = UNMutableNotificationContent()
            // Configure Notification Content
            notificationContent.title = AppConstants.notificationAlertTitle
            //notificationContent.subtitle = abody
            notificationContent.body = aMessage
            //notificationContent.userInfo = infoDict
            
            let notificationTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
            
            // Create Notification Request
            let uuid = UUID().uuidString // Unique ID to each fired location Notification
            let notificationRequest = UNNotificationRequest(identifier: "com.omni.panasonic.bluetoothOff", content: notificationContent, trigger: notificationTrigger)
            
            // Add Request to User Notification Center
            UNUserNotificationCenter.current().add(notificationRequest) { (error) in
                if let error = error {
                    debugPrint("Unable to Add Notification Request (\(error), \(error.localizedDescription))")
                } else {
                    // Save this information in DB
                    let date = Date()
                    let newN:NotifyHistoryInfo = NotifyHistoryInfo()
                    newN.notifyId = uuid
                    newN.notifyDate = date
                    newN.readStatus = "pending"
                    newN.notifyTitle = "Bluetooth off"
                    newN.notifyMessage = aMessage
                    DispatchQueue.main.async {
                        SLRealmManager.sharedInstance.writeNotifyRecord(notify: newN)
                        self.fireUnreadNotify()
                    }
                }
            }
            
        } else {
            // Fallback on earlier versions
            // ios 9
            DispatchQueue.main.async {
                if UIApplication.shared.applicationState == .active || UIApplication.shared.applicationState == .inactive || UIApplication.shared.applicationState == .background {
                    let notification = UILocalNotification()
                    notification.fireDate = Date()
                    notification.alertTitle = AppConstants.notificationAlertTitle
                    notification.alertBody = aMessage //"Hey you! Yeah you! Swipe to unlock!"
                    
                    // Save this information in DB
                    let uuid = UUID().uuidString // Unique ID to each fired Notification
                    // Save this information in DB
                    let date = Date()
                    let newN:NotifyHistoryInfo = NotifyHistoryInfo()
                    newN.notifyId = uuid
                    newN.notifyDate = date
                    newN.sharingStatus = "done"
                    newN.readStatus = "pending"
                    newN.notifyTitle = "Bluetooth off"
                    newN.notifyMessage = aMessage
                    SLRealmManager.sharedInstance.writeNotifyRecord(notify: newN)
                    self.fireUnreadNotify()
                    UIApplication.shared.scheduleLocalNotification(notification)
                }
            }
        }
    }
    
    public func scheduleUnshareNotification(message aMessage : String, body abody : String, trackerID: String) {
        // Create Notification Content
        var infoDict:[String:Any] = [:]
        infoDict["UUID"] = trackerID
        if let device = SLCloudConnector.sharedInstance.devicesList?.sensorArray?.filter({ $0.UUID == trackerID }).first {
            infoDict["alertMode"] = device.alertMode!
            infoDict["pickPocketEnabled"] = device.pickPocketMode!
        }
        if #available(iOS 10.0, *) {
            let notificationContent = UNMutableNotificationContent()
            // Configure Notification Content
            notificationContent.title = AppConstants.notificationAlertTitle
            notificationContent.subtitle = abody
            notificationContent.body = aMessage
            notificationContent.userInfo = infoDict
            notificationContent.categoryIdentifier = AppConstants.unsharingCategoryIdenfier
            // Add Trigger
            let notificationTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
            
            // Create Notification Request
            let uuid = UUID().uuidString // Unique ID to each fired location Notification
            let notificationRequest = UNNotificationRequest(identifier: "com.omni.panasonic.unshare", content: notificationContent, trigger: notificationTrigger)
            
            // Add Request to User Notification Center
            UNUserNotificationCenter.current().add(notificationRequest) { (error) in
                if let error = error {
                    debugPrint("Unable to Add Notification Request (\(error), \(error.localizedDescription))")
                } else {
                    // Save this information in DB
                    let date = Date()
                    let newN:NotifyHistoryInfo = NotifyHistoryInfo()
                    newN.notifyId = uuid
                    newN.notifyDate = date
                    newN.readStatus = "pending"
                    newN.sharingStatus = "done"
                    newN.notifyMessage = aMessage
                    DispatchQueue.main.async {
                        SLRealmManager.sharedInstance.writeNotifyRecord(notify: newN)
                    }
                    // As Device is Unshared, Please Mark it as DONE. No Action needed now.
                    DispatchQueue.main.async {
                        let notifyHistory = (SLRealmManager.sharedInstance.readAllNotifyRecords().filter({ $0.trackerUUID == trackerID}) as [NotifyHistoryInfo])
                        try! SLRealmManager.sharedInstance.realm.write {
                            notifyHistory.forEach({ (notifyRecord) in
                                notifyRecord.sharingStatus = "done"
                            })
                        }
                        self.fireUnreadNotify()
                    }
                }
            }
        } else {
            // Fallback on earlier versions
            // ios 9
            let notification = UILocalNotification()
            notification.fireDate = Date()
            notification.alertBody = aMessage //"Hey you! Yeah you! Swipe to unlock!"
            notification.alertTitle = AppConstants.notificationAlertTitle
            //notification.alertAction = "be awesome!"
            notification.category = AppConstants.unsharingCategoryIdenfier
            notification.soundName = UILocalNotificationDefaultSoundName
            // Save this information in DB
            let uuid = UUID().uuidString // Unique ID to each fired Notification
            // Save this information in DB
            let date = Date()
            let newN:NotifyHistoryInfo = NotifyHistoryInfo()
            newN.notifyId = uuid
            newN.notifyDate = date
            newN.notifyMessage = aMessage
            newN.readStatus = "pending"
            newN.sharingStatus = "done"
            DispatchQueue.main.async {
                SLRealmManager.sharedInstance.writeNotifyRecord(notify: newN)
                self.fireUnreadNotify()
            }
            UIApplication.shared.scheduleLocalNotification(notification)
        }
    }
    
    public func scheduleSharingNotification(message aMessage : String, body abody : String, trackerID: String) {
        // Create Notification Content
        var infoDict:[String:Any] = [:]
        infoDict["UUID"] = trackerID
        if let device = SLCloudConnector.sharedInstance.devicesList?.sensorArray?.filter({ $0.UUID == trackerID }).first {
            infoDict["alertMode"] = device.alertMode!
            infoDict["pickPocketEnabled"] = device.pickPocketMode!
        }
        if #available(iOS 10.0, *) {
            let notificationContent = UNMutableNotificationContent()
            // Configure Notification Content
            notificationContent.title = AppConstants.notificationAlertTitle
            notificationContent.subtitle = abody
            notificationContent.body = aMessage
            notificationContent.userInfo = infoDict
            notificationContent.categoryIdentifier = AppConstants.sharingCategoryIdentifier
            // Add Trigger
            let notificationTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
            
            // Create Notification Request
            let uuid = UUID().uuidString // Unique ID to each fired location Notification
            let notificationRequest = UNNotificationRequest(identifier: "com.omni.panasonic.sharingNotification", content: notificationContent, trigger: notificationTrigger)
            
            // Add Request to User Notification Center
            UNUserNotificationCenter.current().add(notificationRequest) { (error) in
                if let error = error {
                    debugPrint("Unable to Add Notification Request (\(error), \(error.localizedDescription))")
                } else {
                    // Save this information in DB
                    let date = Date()
                    let newN:NotifyHistoryInfo = NotifyHistoryInfo()
                    newN.notifyId = uuid
                    newN.trackerUUID = trackerID
                    newN.sharingStatus = "pending"
                    newN.readStatus = "pending"
                    newN.notifyDate = date
                    newN.notifyMessage = aMessage
                    DispatchQueue.main.async {
                        SLRealmManager.sharedInstance.writeNotifyRecord(notify: newN)
                        self.fireUnreadNotify()
                    }
                }
            }
            // Notification Action
            /*let acceptSharingAction = UNNotificationAction(identifier: AppConstants.sharingAcceptActionIdentifer, title: AppConstants.acceptSharingTitle, options: [])
             let rejectSharingAction = UNNotificationAction(identifier: AppConstants.sharingRejectActionIdentifer, title: AppConstants.rejectSharingTitle, options: [])
             let category = UNNotificationCategory(identifier: AppConstants.sharingCategoryIdentifier, actions: [acceptSharingAction, rejectSharingAction], intentIdentifiers: [], options: [])
             UNUserNotificationCenter.current().setNotificationCategories([category])
             DispatchQueue.main.async {
             UNUserNotificationCenter.current().delegate = AppDelegate.shared
             }*/
        } else {
            // Fallback on earlier versions
            // ios 9
            let notification = UILocalNotification()
            notification.fireDate = Date()
            notification.alertBody = aMessage //"Hey you! Yeah you! Swipe to unlock!"
            notification.alertTitle = AppConstants.notificationAlertTitle
            //notification.alertAction = "be awesome!"
            notification.category = AppConstants.sharingCategoryIdentifier
            notification.soundName = UILocalNotificationDefaultSoundName
            
            let acceptSharingAction = UIMutableUserNotificationAction()
            acceptSharingAction.identifier = AppConstants.sharingAcceptActionIdentifer
            acceptSharingAction.title = AppConstants.acceptSharingTitle
            acceptSharingAction.isDestructive = false
            acceptSharingAction.isAuthenticationRequired = false
            acceptSharingAction.activationMode = .background
            
            let rejectSharingAction = UIMutableUserNotificationAction()
            rejectSharingAction.identifier = AppConstants.sharingRejectActionIdentifer
            rejectSharingAction.title = AppConstants.rejectSharingTitle
            rejectSharingAction.isDestructive = false
            rejectSharingAction.isAuthenticationRequired = false
            rejectSharingAction.activationMode = .background
            
            let category = UIMutableUserNotificationCategory()
            category.identifier = AppConstants.sharingCategoryIdentifier // Identifier passed in the payload
            category.setActions([acceptSharingAction, rejectSharingAction], for: .default)
            
            // Save this information in DB
            let uuid = UUID().uuidString // Unique ID to each fired Notification
            // Save this information in DB
            // Save this information in DB
            let date = Date()
            let newN:NotifyHistoryInfo = NotifyHistoryInfo()
            newN.notifyId = uuid
            newN.trackerUUID = trackerID
            newN.sharingStatus = "pending"
            newN.readStatus = "pending"
            newN.notifyDate = date
            newN.notifyMessage = aMessage
            DispatchQueue.main.async {
                SLRealmManager.sharedInstance.writeNotifyRecord(notify: newN)
                self.fireUnreadNotify()
            }
            UIApplication.shared.scheduleLocalNotification(notification)
        }
    }
    
    public func fireUnreadNotify() {
        NotificationCenter.default.post(
            name: Notification.Name(rawValue: ManagerConstants.updateUnreadKey), object: nil, userInfo: nil)
    }
    
    public func buzzNotification(message aMessage : String, body abody : String, trackerID: String, alertMode: NSNumber) {
        // Create Notification Content
        var infoDict:[String:Any] = [:]
        infoDict["UUID"] = trackerID
        infoDict["alertMode"] = alertMode
        infoDict["alertType"] = "buzz"
        
        if #available(iOS 10.0, *) {
            let notificationContent = UNMutableNotificationContent()
            // Configure Notification Content
            notificationContent.title = AppConstants.notificationAlertTitle
            notificationContent.subtitle = abody
            notificationContent.body = aMessage
            notificationContent.userInfo = infoDict
            notificationContent.categoryIdentifier = AppConstants.buzzingCategoryIdentifier
            //notificationContent.sound = UNNotificationSound.default()
            
            // Add Trigger
            let notificationTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
            
            // Create Notification Request
            let notificationRequest = UNNotificationRequest(identifier: "com.omni.hkconnect.BLEApp.localNotification.buzz", content: notificationContent, trigger: notificationTrigger)
            
            // Add Request to User Notification Center
            UNUserNotificationCenter.current().add(notificationRequest) { (error) in
                if let error = error {
                    debugPrint("Unable to Add Notification Request (\(error), \(error.localizedDescription))")
                } else {
                    // Save this information in DB
                    let date = Date()
                    let newN:NotifyHistoryInfo = NotifyHistoryInfo()
                    newN.notifyId = UUID().uuidString
                    newN.notifyDate = date
                    newN.sharingStatus = "done"
                    newN.readStatus = "pending"
                    newN.notifyMessage = aMessage
                    DispatchQueue.main.async {
                        SLRealmManager.sharedInstance.writeNotifyRecord(notify: newN)
                        self.fireUnreadNotify()
                    }
                }
            }
            
            // Notification Action
            /*let stopBuzzAction = UNNotificationAction(identifier: AppConstants.stopRingingActionIdentifer, title: AppConstants.stopRingingActionTitle, options: [])
             let category = UNNotificationCategory(identifier: AppConstants.buzzingCategoryIdentifier, actions: [stopBuzzAction], intentIdentifiers: [], options: [])
             UNUserNotificationCenter.current().setNotificationCategories([category])
             DispatchQueue.main.async {
             UNUserNotificationCenter.current().delegate = AppDelegate.shared
             }*/
        } else {
            // Fallback on earlier versions
            // ios 9
            DispatchQueue.main.async {
                if UIApplication.shared.applicationState == .active || UIApplication.shared.applicationState == .inactive || UIApplication.shared.applicationState == .background {
                    let notification = UILocalNotification()
                    notification.fireDate = Date()
                    notification.alertTitle = AppConstants.notificationAlertTitle
                    notification.alertBody = aMessage //"Hey you! Yeah you! Swipe to unlock!"
                    //notification.alertAction = "be awesome!"
                    notification.userInfo = infoDict
                    notification.category = AppConstants.buzzingCategoryIdentifier
                    notification.soundName = UILocalNotificationDefaultSoundName
                    
                    let stopBuzzAction = UIMutableUserNotificationAction()
                    stopBuzzAction.identifier = AppConstants.stopRingingActionIdentifer
                    stopBuzzAction.title = AppConstants.stopRingingActionTitle
                    stopBuzzAction.isDestructive = false
                    stopBuzzAction.isAuthenticationRequired = false
                    //stopBuzzAction.activationMode = .background
                    
                    let category = UIMutableUserNotificationCategory()
                    category.identifier = AppConstants.buzzingCategoryIdentifier // Identifier passed in the payload
                    category.setActions([stopBuzzAction], for: .default)
                    
                    // Save this information in DB
                    let uuid = UUID().uuidString // Unique ID to each fired Notification
                    // Save this information in DB
                    let date = Date()
                    let newN:NotifyHistoryInfo = NotifyHistoryInfo()
                    newN.notifyId = uuid
                    newN.notifyDate = date
                    newN.sharingStatus = "done"
                    newN.readStatus = "pending"
                    newN.notifyMessage = aMessage
                    SLRealmManager.sharedInstance.writeNotifyRecord(notify: newN)
                    self.fireUnreadNotify()
                    UIApplication.shared.scheduleLocalNotification(notification)
                }
            }
        }
    }
    
    public func mobileBuzzNotification(message aMessage : String, body abody : String, trackerID: String, alertMode: NSNumber) {
        // Create Notification Content
        var infoDict:[String:Any] = [:]
        infoDict["UUID"] = trackerID
        infoDict["alertMode"] = alertMode
        infoDict["alertType"] = "buzz"
        
        if #available(iOS 10.0, *) {
            let notificationContent = UNMutableNotificationContent()
            // Configure Notification Content
            notificationContent.title = AppConstants.notificationAlertTitle
            notificationContent.subtitle = abody
            notificationContent.body = aMessage
            notificationContent.userInfo = infoDict
            notificationContent.categoryIdentifier = AppConstants.buzzingCategoryIdentifier
            //notificationContent.sound = UNNotificationSound.default()
            
            // Add Trigger
            let notificationTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
            
            // Create Notification Request
            let notificationRequest = UNNotificationRequest(identifier: "com.omni.hkconnect.BLEApp.localNotification.buzz", content: notificationContent, trigger: notificationTrigger)
            
            // Add Request to User Notification Center
            UNUserNotificationCenter.current().add(notificationRequest) { (error) in
                if let error = error {
                    debugPrint("Unable to Add Notification Request (\(error), \(error.localizedDescription))")
                } else {
                    // Save this information in DB
                    let date = Date()
                    let newN:NotifyHistoryInfo = NotifyHistoryInfo()
                    newN.notifyId = UUID().uuidString
                    newN.notifyDate = date
                    newN.sharingStatus = "done"
                    newN.readStatus = "pending"
                    newN.notifyMessage = aMessage
                    DispatchQueue.main.async {
                        SLRealmManager.sharedInstance.writeNotifyRecord(notify: newN)
                        self.fireUnreadNotify()
                    }
                }
            }
            
            // Notification Action
            /*let stopBuzzAction = UNNotificationAction(identifier: AppConstants.stopRingingActionIdentifer, title: AppConstants.stopRingingActionTitle, options: [])
             let category = UNNotificationCategory(identifier: AppConstants.buzzingCategoryIdentifier, actions: [stopBuzzAction], intentIdentifiers: [], options: [])
             UNUserNotificationCenter.current().setNotificationCategories([category])
             DispatchQueue.main.async {
             UNUserNotificationCenter.current().delegate = AppDelegate.shared
             }*/
        } else {
            // Fallback on earlier versions
            // ios 9
            DispatchQueue.main.async {
                if UIApplication.shared.applicationState == .active || UIApplication.shared.applicationState == .inactive || UIApplication.shared.applicationState == .background {
                    let notification = UILocalNotification()
                    notification.fireDate = Date()
                    notification.alertTitle = AppConstants.notificationAlertTitle
                    notification.alertBody = aMessage //"Hey you! Yeah you! Swipe to unlock!"
                    //notification.alertAction = "be awesome!"
                    notification.userInfo = infoDict
                    notification.category = AppConstants.buzzingCategoryIdentifier
                    notification.soundName = UILocalNotificationDefaultSoundName
                    
                    let stopBuzzAction = UIMutableUserNotificationAction()
                    stopBuzzAction.identifier = AppConstants.stopRingingActionIdentifer
                    stopBuzzAction.title = AppConstants.stopRingingActionTitle
                    stopBuzzAction.isDestructive = false
                    stopBuzzAction.isAuthenticationRequired = false
                    //stopBuzzAction.activationMode = .background
                    
                    let category = UIMutableUserNotificationCategory()
                    category.identifier = AppConstants.buzzingCategoryIdentifier // Identifier passed in the payload
                    category.setActions([stopBuzzAction], for: .default)
                    
                    // Save this information in DB
                    let uuid = UUID().uuidString // Unique ID to each fired Notification
                    // Save this information in DB
                    let date = Date()
                    let newN:NotifyHistoryInfo = NotifyHistoryInfo()
                    newN.notifyId = uuid
                    newN.notifyDate = date
                    newN.sharingStatus = "done"
                    newN.readStatus = "pending"
                    newN.notifyMessage = aMessage
                    SLRealmManager.sharedInstance.writeNotifyRecord(notify: newN)
                    self.fireUnreadNotify()
                    UIApplication.shared.scheduleLocalNotification(notification)
                }
            }
        }
    }
    
    static func isApplicationInactive() -> Bool {
        let appState = UIApplication.shared.applicationState
        return appState != UIApplication.State.active
    }
}
