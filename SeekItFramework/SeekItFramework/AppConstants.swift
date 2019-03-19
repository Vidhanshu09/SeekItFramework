//
//  Constants.swift
//  Alamofire
//
//  Created by Jitendra Chamoli on 08/10/18.
//

import Foundation
import UIKit
import Alamofire

public struct ManagerConstants {

    public static let dispatchQueueLabel = "com.panasonic.seekitapp.framework"
    public static let restoreIdentifier = "com.panasonic.seekitapp.restoreIdentifier"
    public static let UUIDStoreKey = "com.panasonic.seekitapp.UUIDStoreKey"
    public static let refreshForDNDKey = "com.panasonic.seekitapp.refreshDNDUINotification"
    public static let refreshStatusKey = "com.panasonic.seekitapp.refreshSensorUINotification"
    public static let buzzerStoppedNotifyKey = "com.panasonic.seekitapp.buzzerStoppedNotifyKeyNotififcation"
    public static let updateUnreadKey = "com.panasonic.seekitapp.refreshUnReadNotificationsUINotification"
    public static let refreshSharedTrackersKey = "com.panasonic.seekitapp.refreshSharedSensorUINotification"
    public static let AddSharedTracker = "com.panasonic.seekitapp.addSharedTracker"

    public static let triggerSOSTriggerKey = "com.panasonic.triggerSOSTriggerKeyNotification"
    public static let logoutTriggerKey = "com.panasonic.sessionExpired.logoutTriggerKeyNotification"
    public static let openCameraByTrackersKey = "com.panasonic.seekitapp.openCameraByTrackersKeyNotification"
    public static let takeSelfieByTrackersKey = "com.panasonic.seekitapp.takeSelfieByTrackersKeyNotification"
    public static let refreshLostLocationKey = "com.panasonic.seekitapp.refreshLostLocationKeyNotification"
    public static let navigateToDeviceDetailKey = "com.panasonic.seekitapp.takeUserTolocationDetailScreenKeyNotification"
    public static let refreshConnectedLocationKey = "com.panasonic.seekitapp.refreshConnectedLocationKeyNotification"
    public static let triggerActionForFDSErrorKey = "com.panasonic.seekitapp.triggerActionForFDSErrorKeyNotification"
    public static let refershMapLocationFullView = "com.panasonic.seekitapp.refershMapLocationFullView"
    public static let refreshAppActiveKey = "com.panasonic.seekitapp.refreshAppActiveKeyNotification"
    public static let pendingFirmwareUpdtNotifyKey = "com.panasonic.seekitapp.pendingfirmwareUpdateNotifiation"

}

public struct DiagConstants {
    
    static let buttonBellObserverKey = "com.panasonic.buttonBellObserverKeyNotification"
    static let sleepAwakeObserverKey = "com.panasonic.sleepAwakeObserverKeyNotification"
}

// For the IssueType
public enum IssueType : String {
    
    case pairingIssue = "Seekit not added"
    case connectingIssue = "Seekit not connecting"
    case buzzingIssue = "Buzzer not working"
    case ledIssue = "LED not working"
    case buttonIssue = "Button not working"
    case firmwareUpdateFailedIssue = "Firmware Update Failed"
}

public enum EventType : String {
    
    case deviceBuzz = "DeviceBuzz"
    case trackerBuzz = "TrackerBuzz"
    case autoConnect = "autoConnect"
    case autoDisconnet = "autoDisconnect"
}

// For the LoginType
public enum LoginType : String {
    case FACEBOOK = "FACEBOOK"
    case GOOGLE = "GOOGLE"
    case CUSTOM = "CUSTOM"
}

// Passcode intervals with rawValue in seconds.
public enum PasscodeInterval: Int {
    case immediately    = 2
    case oneMinute      = 60
    case fiveMinutes    = 300
    case tenMinutes     = 600
    case fifteenMinutes = 900
    case oneHour        = 3600
}

struct Version {
    static let SYS_VERSION_FLOAT = (UIDevice.current.systemVersion as NSString).floatValue
    static let iOS7 = (Version.SYS_VERSION_FLOAT < 8.0 && Version.SYS_VERSION_FLOAT >= 7.0)
    static let iOS8 = (Version.SYS_VERSION_FLOAT >= 8.0 && Version.SYS_VERSION_FLOAT < 9.0)
    static let iOS9 = (Version.SYS_VERSION_FLOAT >= 9.0 && Version.SYS_VERSION_FLOAT < 10.0)
}

// For the SeverConfigType
public enum ServerConfigType : String {
    case PRODUCTION = "PROD"
    case DEV = "DEV"
    case TEST = "TEST"
}

let serverConfig = ServerConfigType.PRODUCTION

public struct AppConstants {
    
    public static let FxAiOSClientId = "1b1a3e44c54fbb58"
    //public static let BASEURL = "https://34.208.196.152:5000/api" // Prod Environment
    //public static let BASEURL = "https://13.59.36.23:5000/api"    // Dev Environment
    
    public static let FeedbackBASEURL = "https://panasonictracker.atlassian.net"
    
    public static let ServifyBASEURL = "https://node.servify.in/publicapi/api"
    
    public static let BASEURL  = { () -> String in
        switch serverConfig.rawValue {
        case ServerConfigType.PRODUCTION.rawValue:      // Prod Environment
            return "https://www.seekittracker.panasonic.com/api"
        //return "https://34.208.196.152:5000/api"
        case ServerConfigType.DEV.rawValue:             // Dev Environment
            return "https://13.59.36.23:5000/api"
        case ServerConfigType.TEST.rawValue:            // Test Environment
            return "https://192.168.5.53:5000/api"
        default:
            return ""
        }
    }
    public static let BASE_SERVER_IP  = { () -> String in
        switch serverConfig.rawValue {
        case ServerConfigType.PRODUCTION.rawValue:      // Prod Environment
            return "34.208.196.152"
        case ServerConfigType.DEV.rawValue:             // Dev Environment
            return "13.59.36.23"
        case ServerConfigType.TEST.rawValue:            // Test Environment
            return "192.168.5.53"
        default:
            return ""
        }
    }
    
    //serverConfig.rawValue == "Dev" ? "https://192.168.5.162:5000/api" : "https://34.208.196.152:5000/api"
    public static let contentType = ["content-type" : "application/json"]
    public static let deviceTokenOld = "D2B58D14F54FF5EAF3E5FE0C341C79BC91685EBE2192582972C9DBDB3EE29E44"
    public static let deviceTokenNew = "07649A5D9051A4C0E3B18FA8A8C17122C49A7A78E23E00328DC7EE6E8C62D287"
    
    // UserDefault Storage Keys
    public static let fcmDeviceTokenKey:String = "fcmDeviceRegistrationKey"
    public static let pinCodeKey:String = "postalCodeKey"
    public static let addressKey:String = "mailAddressKey"
    public static let displayAddress:String = "addressKey"
    public static let isUserLoggedInKey:String = "isUserLoggedInKey"
    public static let deviceAsBeaconEnabledKey:String = "deviceAsBeaconEnabledKey"
    public static let isErrorWhileGettingSensorListKey:String = "isErrorWhileGettingSensorListKey"
    public static let userFirstNameKey:String = "userFirstNameKey"
    public static let userLastNameKey:String = "userLastNameKey"
    public static let mobileNumberKey:String = "mobileNumberKey"
    public static let countryCodeKey:String = "countryCodeKey"
    public static let userEmailKey:String = "userEmailKey"
    public static let userIDKey:String = "uniqueUserIDKey"
    public static let userPictureKey:String = "userPictureKey"
    public static let loginTypeKey:String = "loginType"
    public static let sessionKeyForSignedUser:String = "sessionKeyForSignedUser"
    public static let servifySessionKeyForSignedUser:String = "servifySessionKeyForSignedUser"
    public static let pictureURLUser:String = "pictureURLKey"
    public static let isWiFiSafeZoneEnabled:String = "isWifiSafeZoneEnabledKey"
    public static let isSOSModeEnabledKey:String = "isSOSModeEnabledKey"
    public static let userShopRegister:String = "userShopRegister"
    public static let notificationBellIcon:String = "notificationBellIcon"
    public static let DashboardToolTipDone:String = "DashboardToolTipDone"
    public static let SettingsToolTipDone:String = "SettingsToolTipDone"
    public static let phoneDetailsToolTipDone:String = "phoneDetailsToolTipDone"
    public static let DeviceDetailsToolTipDone:String = "DeviceDetailsToolTipDone"
    public static let showDisclaimerForPickPocketModeKey:String = "showDisclaimerForPickPocketModeKey"
    public static let showDisclaimerForLToHModeKey:String = "showDisclaimerForLToHModeKey"
    public static let latestFirmwareVersionKey:String = "latestFirmwareVersionKey"
    
    public static let missingEmail:String = "Please enter email"
    
    public static let offlineMessage:String = "Make sure you are connected to Internet"
    public static let sslError:String = "An SSL error has occurred and a secure connection to the server cannot be made."
    public static let noContactsFound:String = "No SOS contact found"
    
    // Frequently Used Colours in the App
    public static let connectedColor = UIColor(red: CGFloat(18.0/255.0), green: CGFloat(195.0/255.0), blue: CGFloat(105.0/255.0), alpha: 1)
    public static let disconnectedColor = UIColor(red: CGFloat(138.0/255.0), green: CGFloat(161.0/255.0), blue: CGFloat(188.0/255.0), alpha: 1)
    public static let lostColor = UIColor(red: CGFloat(221.0/255.0), green: CGFloat(75.0/255.0), blue: CGFloat(57.0/255.0), alpha: 1)
    public static let cardViewBackColor = UIColor(red: CGFloat(224.0/255.0), green: CGFloat(235.0/255.0), blue: CGFloat(243.0/255.0), alpha: 1)
    public static let cardViewWhiteColor = UIColor(red: CGFloat(255.0/255.0), green: CGFloat(255.0/255.0), blue: CGFloat(255/255.0), alpha: 1)
    public static let yellowColor = UIColor(red: CGFloat(255.0/255.0), green: CGFloat(209.0/255.0), blue: CGFloat(0.0/255.0), alpha: 1)
    public static let ringStrokeColor = UIColor(red: CGFloat(40.0/255.0), green: CGFloat(0.0/255.0), blue: CGFloat(86.0/255.0), alpha: 1)
    public static let seekBorderColor = UIColor(red: 238/255, green: 238/255, blue: 238/255, alpha: 1.0)
    public static let seekBorderDarkColor = UIColor(red: 204/255, green: 204/255, blue: 204/255, alpha: 1.0)
    public static let seekGreenColor = UIColor(red: 126/255, green: 211/255, blue: 33/255, alpha: 1.0)
    public static let seekOrangeColor = UIColor(red: 245/255, green: 166/255, blue: 35/255, alpha: 1.0)
    public static let seekRedColor = UIColor(red: 225/255, green: 31/255, blue: 55/255, alpha: 1.0)
    public static let seekTextLightColor = UIColor(red: 149/255, green: 149/255, blue: 149/255, alpha: 1.0)
    
    // UIView Title Color
    public static let navigationBackColor = UIColor.white
    public static let titleBackColor = UIColor(red: CGFloat(0.0/255.0), green: CGFloat(86.0/255.0), blue: CGFloat(168.0/255.0), alpha: 1)
    public static let dashboardBGColor = UIColor(red: CGFloat(235.0/255.0), green: CGFloat(243.0/255.0), blue: CGFloat(252.0/255.0), alpha: 0.8)
    public static let attributedForeGroundTextColor = UIColor(red: 43.0 / 255.0, green: 165.0 / 255.0, blue: 247.0 / 255.0, alpha: 1.0)
    public static let notifyBGColor = UIColor(red: CGFloat(235.0/255.0), green: CGFloat(243.0/255.0), blue: CGFloat(252.0/255.0), alpha: 1)
    
    // Cell Colors
    public static let cardViewBGColor = UIColor(red: CGFloat(235.0/255.0), green: CGFloat(243.0/255.0), blue: CGFloat(252.0/255.0), alpha: 0.0)
    
    // Notification Keys
    public static let bluetoothPowerOffNotification:String =  "com.panasonic.seekitapp.B.powerOff"
    public static let bluetoothPoweredOnNotification:String = "com.panasonic.seekitapp.B.powerOn"
    
    // Notification Identifiers
    
    public static let SensorConnected = "SensorConnected"
    public static let SensorDisConnected = "SensorDisConnected"
    
    public static let notificationAlertTitle = "PanasonicTracker"
    public static let sharingCategoryIdentifier = "1"
    public static let sharingAcceptActionIdentifer = "acceptSharing"
    public static let acceptSharingTitle = "ACCEPT SHARING"
    public static let rejectSharingTitle = "REJECT SHARING"
    public static let sharingRejectActionIdentifer = "rejectSharing"
    
    public static let stopRingingActionIdentifer = "stopRinging"
    public static let stopRingingActionTitle = "Stop Buzzing"
    public static let buzzingCategoryIdentifier = "buzzing"
    
    public static let unsharingCategoryIdenfier = "unshareNotification"
    public static let disconnectCategoryIdentifer = "sensorDisconnected"
    public static let markAsLostActionIdentifer = "markSensorAsLost"
    public static let markAsLostActionTitle = "Mark as Lost"
    public static let sessionExpiredCategoryIdenfier = "sessionExpired"
    
    public static let lowBatteryAlertCategoryIdenfier = "lowBatteryAlert"
    
    // Constant Values
    public static let HIGH_ALERT_MODE:NSNumber = 3
    public static let LOW_ALERT_MODE:NSNumber = 0
    
    // Diagnostic Actions
    //    public static let pairingIssue      =   "Seekit not added"
    //    public static let connectingIssue   =   "Seekit not connecting"
    //    public static let buzzingIssue      =   "Buzzer not working"
    //    public static let ledIssue          =   "LED not working"
    //    public static let buttonIssue       =   "Button not working"
}

enum Router: URLRequestConvertible {
    case createUser(parameters: Parameters)
    case readUser(username: String)
    case updateUser(username: String, parameters: Parameters)
    case destroyUser(username: String)
    
    static let baseURLString = "https://34.208.196.152:5000/api"
    
    var method: HTTPMethod {
        switch self {
        case .createUser:
            return .post
        case .readUser:
            return .get
        case .updateUser:
            return .put
        case .destroyUser:
            return .delete
        }
    }
    
    var path: String {
        switch self {
        case .createUser:
            return "/userRegisteration"
        case .readUser(let username):
            return "/users/\(username)"
        case .updateUser(let username, _):
            return "/users/\(username)"
        case .destroyUser(let username):
            return "/users/\(username)"
        }
    }
    
    // MARK: URLRequestConvertible
    
    func asURLRequest() throws -> URLRequest {
        let url = try Router.baseURLString.asURL()
        
        var urlRequest = URLRequest(url: url.appendingPathComponent(path))
        urlRequest.httpMethod = method.rawValue
        
        switch self {
        case .createUser(let parameters):
            urlRequest = try URLEncoding.default.encode(urlRequest, with: parameters)
        case .updateUser(_, let parameters):
            urlRequest = try URLEncoding.default.encode(urlRequest, with: parameters)
        default:
            break
        }
        return urlRequest
    }
}
