//
//  CloudConnector.swift
//  SeekLib
//
//  Created by Jitendra Chamoli on 09/10/18.
//

import Foundation
import UIKit
import Alamofire
import AlamofireImage
import SwiftyJSON
import CocoaLumberjack
import SSZipArchive
import Locksmith

// Closure for Response and Error Handling
public typealias SuccessHandler = (_ response: JSON?) -> Void
public typealias ErrorHandler = (_ error: Error?) -> Void
public typealias FinishedHandler = () -> Void
public typealias ImageHandler = (_ response: UIImage?) -> Void

public class SLCloudConnector: NSObject {
    
    /**
     Shared instance for Cloud APIs
     */
    public static let sharedInstance = SLCloudConnector()
    
    // Network Manager that will be used to request HTTPS SSL Webserver API
    let networkManager = NetworkManager.sessionManager
    let defaults = UserDefaults.standard
    public var userProfile:TAUserProfileModel?
    public var shareHistory:TAHistoryList?
    public var devicesList:TASensorList?
    public var wifiList:TAWifiList?
    public var sleeptime:TASleepModel?
    public var sosContacts:TAContactList?
    public var raiseTickets:TARaiseTicketList?
    public var uuidObj:TAUUIDModel?
    public var latestFirmwareVersion : String {
        set {
            UserDefaults.standard.set(newValue, forKey: AppConstants.latestFirmwareVersionKey)
            UserDefaults.standard.synchronize()
        }
        get {
            return UserDefaults.standard.string(forKey: AppConstants.latestFirmwareVersionKey) ?? "4.4.9"
        }
    }
    
    /// Trigger LogOut Action When User Session is expired.
    func triggerLogOut() {
        NotificationCenter.default.post(
            name: Notification.Name(rawValue: ManagerConstants.logoutTriggerKey), object: nil, userInfo: nil)
    }
    
    /**
     Change Refreshed FCM Token on Server.
     /// - Parameters:
     ///   - fcmToken: Updated FCM Token String
     ///   - success: Success Block
     ///   - failure: Failure Block
     */
    
    public func registerFCMTokenOnServer(fcmToken: String!, success: SuccessHandler!, failure: ErrorHandler!) {
        
        let updateFCMTokenUrl = String(format: "%@/fcmToken", AppConstants.BASEURL())
        var fcmDict: [String: Any] = [:]
        var sessonKey = ""
        if let sessionK = UserDefaults.standard.string(forKey: AppConstants.sessionKeyForSignedUser) {
            sessonKey = sessionK
        }
        fcmDict["pushNotfToken"] = fcmToken
        DDLogVerbose("update user Info by calling \(updateFCMTokenUrl)");
        networkManager.request(updateFCMTokenUrl, method: .put, parameters: fcmDict, encoding: JSONEncoding.prettyPrinted, headers: ["content-type" : "application/json", "sessionkey" : sessonKey]).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if (jsonObj["errCode"].int == 0) {
                        success(jsonObj["data"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    public func updatePriority(addWights: [String: Any], success: SuccessHandler!, failure: ErrorHandler!) {
        
        let url = String(format: "%@/tracker/weight", AppConstants.BASEURL())
        var sessonKey = ""
        if let sessionK = UserDefaults.standard.string(forKey: AppConstants.sessionKeyForSignedUser) {
            sessonKey = sessionK
        }
        DDLogVerbose("updatePriority called \(url)");
        
        networkManager.request(url, method: .put, parameters: addWights, encoding: JSONEncoding.prettyPrinted, headers: ["content-type" : "application/json", "sessionkey" : sessonKey]).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if (jsonObj["errCode"].int == 0) {
                        success(jsonObj["data"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                        if (jsonObj["errCode"].int == -1) {
                            DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                            self.triggerLogOut()
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    //-------------UserFeedback API Calls---------------------
    //--------------------------------------------------------
    
    /**
     Post User Feedback on Server.
     /// - Parameters:
     ///   - success: Success Block
     ///   - failure: Failure Block
     */
    
    public func userFeedBack(userInfoDict: [String: Any], success: SuccessHandler!, failure: ErrorHandler!) {
        let userFeedbackUrl = String(format: "%@/rest/api/2/issue", AppConstants.FeedbackBASEURL)
        DDLogVerbose("requesting feedback with \(userFeedbackUrl)");
        networkManager.request(userFeedbackUrl, method: .post, parameters: userInfoDict, encoding: JSONEncoding.prettyPrinted, headers: AppConstants.contentType).responseJSON(completionHandler: { (response) in
            
            print(response)
            
            if let err = response.result.error {
                failure(err)
            } else {
                
                print(response.result.value!)
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if let data = jsonObj["data"].string {
                        print(data)
                    }
                    success(jsonObj)
                    
                } else {
                    // Handle Nil
                    failure(nil)
                    //failure(error)
                }
                
            }
        })
    }
    
    //--------------------------
    // ==========================================================================
    // MARK:- Social, Custom Login & User Account Authentication
    // ==========================================================================
    
    /**
     Custom Login - Called when User already have Custom Login Credentials
     
     - Parameters:
     - loginData: Contains Provided Email and Password Values
     - success: Success Block
     - failure: Failure Block
     */
    public func loginUserWithCustomData(loginData:TAUserLoginData!, success: SuccessHandler!, failure: ErrorHandler!) {
        
        DDLogVerbose("\(#function) Login with Email ############\n")
        var dict: [String: Any] = [:]
        dict["userName"] = loginData.userId
        dict["password"] = loginData.password
        dict["pushNotfToken"] = loginData.pushToken // Updates FCM Token on each login.
        let customLoginUrl = String(format: "%@/userLogin", AppConstants.BASEURL())
        DDLogVerbose("requesting Login with \(customLoginUrl)");
        
        networkManager.request(customLoginUrl, method: .post, parameters: dict, encoding: JSONEncoding.prettyPrinted, headers: AppConstants.contentType).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if (jsonObj["errCode"].int == 0) {
                        self.userProfile = TAUserProfileModel(userData: jsonObj["data"])
                        self.updatePhoneToken()
                        success(jsonObj["data"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            if (errorMessage == "User not verified") {
                                if let sessionKey = jsonObj["data"]["sessionKey"].string {
                                    UserDefaults.standard.set(sessionKey, forKey: AppConstants.sessionKeyForSignedUser)
                                    UserDefaults.standard.synchronize()
                                }
                            }
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    public func updatePhoneToken() {
        let keyChainID = Locksmith.loadDataForUserAccount(userAccount: Bundle.main.object(forInfoDictionaryKey:"CFBundleName") as! String)
        if let retriveuuid = keyChainID?["deviceUniqueID"] as? String, let _ = keyChainID?["deviceName"] as? String  {
            var updateDict: [String: Any] = [:]
            updateDict["UUID"] = retriveuuid
            updateDict["pushNotfToken"] = UserDefaults.standard.string(forKey: AppConstants.fcmDeviceTokenKey)
            
            SLCloudConnector.sharedInstance.updateTrackerDeviceInfo(updateDict: updateDict, success: { (successDict) in
                DispatchQueue.main.async {
                    DDLogVerbose("Tracker Alert Mode Updated Successfully")
                }
            }) { (errorDict) in
                if let errorMessage = errorDict?.localizedDescription, errorMessage != AppConstants.sslError {
                    DDLogVerbose("Tracker Alert Mode Update failed!!!! -> \(String(describing: errorMessage))")
                } else {
                    DDLogVerbose("Tracker Alert Mode Update failed!!!! -> \(String(describing: AppConstants.offlineMessage))")
                }
            }
        }
    }
    
    // MARK:- Create User Account - Email, Social(Google, Facebook)
    /**
     Create Account - Create User's Account Using some Basic Information
     
     - Parameters:
     - userInfoDict: contains required parameters for creating User Account
     - success: Success Block
     - failure: Failure Block
     */
    public func createAccount(userInfoDict: [String: Any], success: SuccessHandler!, failure: ErrorHandler!) {
        let userRegistrationUrl = String(format: "%@/userRegisteration", AppConstants.BASEURL())
        DDLogVerbose("requesting Login with \(userRegistrationUrl)");
        networkManager.request(userRegistrationUrl, method: .post, parameters: userInfoDict, encoding: JSONEncoding.prettyPrinted, headers: AppConstants.contentType).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if let sessionKey = jsonObj["data"]["sessionKey"].string {
                        UserDefaults.standard.set(sessionKey, forKey: AppConstants.sessionKeyForSignedUser)
                        UserDefaults.standard.synchronize()
                    }
                    if (jsonObj["errCode"].int == 0) && (jsonObj["errMessage"].string != "OTP is send Please verify") {
                        self.userProfile = TAUserProfileModel(userData: jsonObj["data"])
                        success(jsonObj["data"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    // MARK:- Update User Info API
    
    /**
     Update Account - Update User's Account Info and Password
     
     - Parameters:
     - dict: contains parameters that will be updated
     - success: Success Block
     - failure: Failure Block
     */
    public func updateAccount(dict: [String: Any], success: SuccessHandler!, failure: ErrorHandler!) {
        
        let updateInfoUrl = String(format: "%@/userProfile", AppConstants.BASEURL())
        var sessonKey = ""
        if let sessionK = UserDefaults.standard.string(forKey: AppConstants.sessionKeyForSignedUser) {
            sessonKey = sessionK
        }
        DDLogVerbose("update user Info by calling \(updateInfoUrl)");
        networkManager.request(updateInfoUrl, method: .put, parameters: dict, encoding: JSONEncoding.prettyPrinted, headers: ["content-type" : "application/json", "sessionkey" : sessonKey]).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    //print(jsonObj)
                    if (jsonObj["errCode"].int == 0) {
                        /*if let sessionKey = jsonObj["data"]["sessionKey"].string {
                         UserDefaults.standard.set(sessionKey, forKey: AppConstants.sessionKeyForSignedUser)
                         UserDefaults.standard.synchronize()
                         }*/
                        //self.userProfile = TAUserProfileModel(userData: jsonObj["data"])
                        success(jsonObj["data"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                        if (jsonObj["errCode"].int == -1) {
                            DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                            self.triggerLogOut()
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    // MARK:- Get Updated User Information
    /**
     Get Updated User Info - Get User's Account Info
     
     - Parameters:
     - success: Success Block
     - failure: Failure Block
     */
    public func getUpdatedUserInfo(success: SuccessHandler!, failure: ErrorHandler!) {
        let getUserInfoUrl = String(format: "%@/userProfile", AppConstants.BASEURL())
        var sessonKey = ""
        if let sessionK = UserDefaults.standard.string(forKey: AppConstants.sessionKeyForSignedUser) {
            sessonKey = sessionK
        }
        DDLogVerbose("Retrieving Updated User Info using: \(getUserInfoUrl)");
        networkManager.request(getUserInfoUrl, method: .get, parameters: nil, encoding: URLEncoding.default, headers: ["content-type" : "application/json", "sessionkey" : sessonKey]).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if (jsonObj["errCode"].int == 0) {
                        self.userProfile = TAUserProfileModel(userData: jsonObj["data"])
                        success(jsonObj["data"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                        if (jsonObj["errCode"].int == -1) {
                            DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                            self.triggerLogOut()
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    // MARK:- Register Tracker
    
    /**
     Register Tracker on Server
     
     - Parameters:
     - trackerID: tracker UUID that needs to be registered
     - trackerName: tracker Name given by User
     - success: Success Block
     - failure: Failure Block
     */
    public func registerTrackerDevice(trackerInfoDict:[String: Any]!, success: SuccessHandler!, failure: ErrorHandler!) {
        
        var sessonKey = ""
        if let sessionK = UserDefaults.standard.string(forKey: AppConstants.sessionKeyForSignedUser) {
            sessonKey = sessionK
        }
        let trackerRegistrationUrl = String(format: "%@/tracker", AppConstants.BASEURL())
        DDLogVerbose("Adding sensor by calling \(trackerRegistrationUrl)");
        networkManager.request(trackerRegistrationUrl, method: .post, parameters: trackerInfoDict, encoding: JSONEncoding.prettyPrinted, headers: ["content-type" : "application/json", "sessionkey" : sessonKey]).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if (jsonObj["errCode"].int == 0) {
                        success(jsonObj["data"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                        if (jsonObj["errCode"].int == -1) {
                            DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                            self.triggerLogOut()
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    //
    
    // MARK:- Update Tracker
    
    /**
     Udpate Tracker details on Server
     
     - Parameters:
     - updateDict: tracker Update Info Dictionary
     - success: Success Block
     - failure: Failure Block
     */
    public func updateTrackerDeviceInfo(updateDict: [String: Any], success: SuccessHandler!, failure: ErrorHandler!) {
        //print(updateDict)
        var sessonKey = ""
        if let sessionK = UserDefaults.standard.string(forKey: AppConstants.sessionKeyForSignedUser) {
            sessonKey = sessionK
        }
        let trackerUpdateUrl = String(format: "%@/tracker", AppConstants.BASEURL())
        DDLogVerbose("Updating sensor details by calling \(trackerUpdateUrl)");
        networkManager.request(trackerUpdateUrl, method: .put, parameters: updateDict, encoding: JSONEncoding.prettyPrinted, headers: ["content-type" : "application/json", "sessionkey" : sessonKey]).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if (jsonObj["errCode"].int == 0) {
                        success(jsonObj["data"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                        if (jsonObj["errCode"].int == -1) {
                            DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                            self.triggerLogOut()
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    // MARK:- Verify OTP
    
    /**
     Verify OTP
     
     - Parameters:
     - optCode: One Time Code that User Has recieved
     - userName: UserID for User
     - success: Success Block
     - failure: Faiure Block
     */
    public func verifyOTP(optCode: String!, userName: String!, success: SuccessHandler!, failure: ErrorHandler!) {
        let optVerificationURL = String(format: "%@/otp", AppConstants.BASEURL())
        DDLogVerbose("Calling Put Method at URL \(optVerificationURL) for OTP verification")
        var body: [String: Any] = [:]
        body["otp"] = optCode
        body["userName"] = userName
        
        networkManager.request(optVerificationURL, method: .put, parameters: body, encoding: JSONEncoding.prettyPrinted, headers: ["content-type" : "application/json"]).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if (jsonObj["errCode"].int == 0) {
                        if let sessionKey = jsonObj["data"]["sessionKey"].string {
                            UserDefaults.standard.set(sessionKey, forKey: AppConstants.sessionKeyForSignedUser)
                            UserDefaults.standard.synchronize()
                        }
                        success(jsonObj["items"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                        if (jsonObj["errCode"].int == -1) {
                            DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                            self.triggerLogOut()
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    // MARK:- Reset Password
    
    /**
     Reset Password
     
     - Parameters:
     - userName: UserID
     - success: Success Block
     - failure: Failure Block
     */
    public func resetPassword(userName:String!, success: SuccessHandler!, failure: ErrorHandler!) {
        
        let resetPasswordURL = String(format: "%@/resetPassword?userName=%@", AppConstants.BASEURL(), userName)
        
        networkManager.request(resetPasswordURL, method: .post, parameters: nil, encoding: JSONEncoding.prettyPrinted, headers:["content-type" : "application/json"]).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if (jsonObj["errCode"].int == 0) {
                        if let sessionKey = jsonObj["data"]["sessionKey"].string {
                            UserDefaults.standard.set(sessionKey, forKey: AppConstants.sessionKeyForSignedUser)
                            UserDefaults.standard.synchronize()
                        }
                        success(jsonObj)
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                        if (jsonObj["errCode"].int == -1) {
                            DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                            self.triggerLogOut()
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    // MARK:- Set New Password
    
    /**
     Set New Password for User
     
     - Parameters:
     - password: Updated Password for User
     - success: Success Block
     - failure: Failure Block
     */
    public func setPassword(password:String!, success: SuccessHandler!, failure: ErrorHandler!) {
        
        let resetPasswordURL = String(format: "%@/setPassword?password=%@", AppConstants.BASEURL(), password)
        var sessonKey = ""
        if let sessionK = UserDefaults.standard.string(forKey: AppConstants.sessionKeyForSignedUser) {
            sessonKey = sessionK
        }
        
        networkManager.request(resetPasswordURL, method: .post, parameters: nil, encoding: JSONEncoding.prettyPrinted, headers:["content-type" : "application/json", "sessionkey" : sessonKey]).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if (jsonObj["errCode"].int == 0) {
                        self.userProfile = TAUserProfileModel(userData: jsonObj["data"])
                        success(jsonObj["data"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                        if (jsonObj["errCode"].int == -1) {
                            DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                            self.triggerLogOut()
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    // MARK:- Resend OTP
    
    /**
     Resend OTP
     
     - Parameters:
     - userName: UserID
     - success: Success Block
     - failure: Failure Block
     */
    public func resendOTP(userName:String!, success: SuccessHandler!, failure: ErrorHandler!) {
        
        let resendOTPURL = String(format: "%@/otp?userName=%@", AppConstants.BASEURL(), userName)
        networkManager.request(resendOTPURL, method: .get, parameters: nil, encoding: URLEncoding.default, headers:["content-type" : "application/json"]).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if (jsonObj["errCode"].int == 0) {
                        success(jsonObj["items"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                        if (jsonObj["errCode"].int == -1) {
                            DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                            self.triggerLogOut()
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    // MARK:- Download More RingTones
    
    /**
     Download More RingTones
     
     - Parameters:
     - timeStamp: Current Time in Epoch Time in miliseconds
     - success: Success Block
     - failure: Failure Block
     */
    public func downloadRingTones(timeStamp:String!, success: SuccessHandler!, failure: ErrorHandler!) {
        
        var sessionKey = ""
        if let sessionK = UserDefaults.standard.string(forKey: AppConstants.sessionKeyForSignedUser) {
            sessionKey = sessionK
        }
        let downloadRingToneURL = String(format: "%@/downloadRingTone", AppConstants.BASEURL())
        let destinationPath: DownloadRequest.DownloadFileDestination = { _, _ in
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsURL.appendingPathComponent("ringtones.zip")
            return (fileURL, [.removePreviousFile, .createIntermediateDirectories])
        }
        networkManager.download(downloadRingToneURL, method: .get, parameters: nil, encoding: URLEncoding.default, headers: ["content-type" : "application/json", "sessionkey" : sessionKey], to: destinationPath).downloadProgress(closure: { (progress) in
            //progress closure
            //print("Progress: \(progress.fractionCompleted)")
        }).validate().responseData { ( response ) in
            if let err = response.result.error {
                DDLogVerbose("Downloaded RingTone due to error \(err.localizedDescription)")
                failure(err)
            } else {
                if (response.result.value != nil) {
                    DDLogVerbose("Downloaded RingTone.zip Folder from server...")
                    DDLogVerbose("Full URL:- \(response.destinationURL!)")
                    DDLogVerbose("Downloaded Filename:-> \(response.destinationURL!.lastPathComponent)")
                    // Unzip
                    DDLogVerbose("RingTone Zip file size = \(response.destinationURL!.fileSize)")
                    DDLogVerbose("Zip Location:- \(response.destinationURL!.path)")
                    let extractPath = self.getAbsoulutePath(ringTonePath: "ringtones")
                    DDLogVerbose("Extract Path :- \(extractPath)")
                    let filemgr = FileManager.default
                    let dirPaths = filemgr.urls(for: .documentDirectory, in: .userDomainMask)
                    let docsDir = dirPaths[0]
                    print(docsDir)
                    do {
                        try SSZipArchive.unzipFile(atPath: response.destinationURL!.path, toDestination: extractPath, overwrite: true, password: nil)
                        DDLogVerbose("Unzip \(String(describing: success))")
                    } catch {
                        DDLogVerbose("Error Occured while Extracting file")
                    }
                    if let list = self.listFilesFromDocumentsFolder() {
                        DDLogVerbose("Extracted Zipped Ringtone Folder")
                        DDLogVerbose("New RingTones:- \(list)")
                        self.getLatestFirmwareInfo()
                    }
                    success(JSON(response))
                } else {
                    // Handle Nil
                    failure("Unknown Error")
                    DDLogVerbose("Downloaded RingTone due to unkown error")
                }
            }
        }
    }
    
    
    // MARK:- FIRMWARE RELATED APIS
    
    /**
     // Get Lateset Firmware Details
     
     - Parameters:
     - success: Success Block
     - failure: Failure Block
     */
    public func getLatestFirmwareInfo(success: SuccessHandler!, failure: ErrorHandler!) {
        
        let getLatestFirmwareInfoURL = String(format: "%@/firmware", AppConstants.BASEURL())
        var sessionKey = ""
        if let sessionK = UserDefaults.standard.string(forKey: AppConstants.sessionKeyForSignedUser) {
            sessionKey = sessionK
        }
        
        DDLogVerbose("Getttings details about latest firmware from  server | \(getLatestFirmwareInfoURL)");
        networkManager.request(getLatestFirmwareInfoURL, method: .get, parameters: nil, encoding: URLEncoding.default, headers: ["content-type" : "application/json", "sessionkey" : sessionKey]).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if (jsonObj["errCode"].int == 0) {
                        if let version = jsonObj["data"]["firmwareVersion"].string {
                            self.latestFirmwareVersion = version
                            DDLogVerbose("****************************************************")
                            DDLogVerbose("********* LATEST FIRMWARE ON SERVER IS:- \(version)")
                            DDLogVerbose("****************************************************")
                        }
                        success(jsonObj["items"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                        if (jsonObj["errCode"].int == -1) {
                            DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                            self.triggerLogOut()
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    /**
     Download DFU Zip for DFU Firmware ATA Update
     
     - Parameters:
     - success: Success Block
     - failure: Failure Block
     */
    
    public func downloadDFUZip(success: SuccessHandler!, failure: ErrorHandler!) {
        
        //var dict: [String: Any] = [:]
        var sessionKey = ""
        if let sessionK = UserDefaults.standard.string(forKey: AppConstants.sessionKeyForSignedUser) {
            sessionKey = sessionK
        }
        //let downloadFirmwareURL = String(format: "%@/downloadFirmware?firmwareName=4.4.1", AppConstants.BASEURL())
        let downloadFirmwareURL = String(format: "%@/downloadFirmware?firmwareName=\(latestFirmwareVersion)", AppConstants.BASEURL())
        let destinationPath: DownloadRequest.DownloadFileDestination = { _, _ in
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsURL.appendingPathComponent("\(self.latestFirmwareVersion).zip")
            return (fileURL, [.removePreviousFile, .createIntermediateDirectories])
        }
        networkManager.download(downloadFirmwareURL, method: .get, parameters: nil, encoding: URLEncoding.default, headers: ["content-type" : "application/json", "sessionkey" : sessionKey], to: destinationPath).downloadProgress(closure: { (progress) in
            //progress closure
            //print("Progress: \(progress.fractionCompleted)")
        }).validate().responseData { ( response ) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    if let firmDetailDict = response.response?.allHeaderFields, let vers = firmDetailDict["Content-Disposition"] as? String {
                        DDLogVerbose("****************************************************")
                        print("Firmware Detail:- \(vers)")
                        DDLogVerbose("DFUTest:- Downloaded Firmware Detail:- \(vers)")
                        DDLogVerbose("****************************************************")
                    }
                    DDLogVerbose("Downloaded dfu.zip Folder from server...")
                    DDLogVerbose("Full URL:- \(response.destinationURL!)")
                    DDLogVerbose("Downloaded Filename:-> \(response.destinationURL!.lastPathComponent)")
                    // Unzip
                    DDLogVerbose("DFU Zip file size = \(response.destinationURL!.fileSize)")
                    DDLogVerbose("DFU Zip Location:- \(response.destinationURL!.path)")
                    let extractPath = self.getAbsoulutePath(ringTonePath: "firmware")
                    DDLogVerbose("Extract Path :- \(extractPath)")
                    let filemgr = FileManager.default
                    let dirPaths = filemgr.urls(for: .documentDirectory, in: .userDomainMask)
                    let docsDir = dirPaths[0]
                    print(docsDir)
                    /*do {
                     try SSZipArchive.unzipFile(atPath: response.destinationURL!.path, toDestination: extractPath, overwrite: true, password: nil)
                     DDLogVerbose("Unzip \(success)")
                     } catch {
                     DDLogVerbose("Error Occured while Extracting file")
                     }*/
                    //if let list = self.listFilesFromDocumentsFolder() {
                    //    DDLogVerbose("Extracted Zipped Firmware Folder")
                    //    //DDLogVerbose("New RingTones:- \(list)")
                    //}
                    success(JSON(response))
                } else {
                    // Handle Nil
                    failure("Unknown Error")
                }
            }
        }
    }
    // MARK:- Get Tracker List
    
    /**
     Get List of Trackers for User from Server
     - Parameters:
     - sessonKey: session Key for Logged in User
     - userName: UserID
     - success: Success Block
     - failure: Faiure Block
     */
    public func getTrackerList(sessonKey:String!, userName: String, success: SuccessHandler!, failure: ErrorHandler!) {
        //print(sessonKey)
        //var dict: [String: Any] = [:]
        //dict["userName"] = userName
        let trackerRegistrationUrl = String(format: "%@/tracker", AppConstants.BASEURL())
        DDLogVerbose("getting \(userName)'s list of sensors from  server | \(trackerRegistrationUrl)");
        networkManager.request(trackerRegistrationUrl, method: .get, parameters: nil, encoding: URLEncoding.default, headers: ["content-type" : "application/json", "sessionkey" : sessonKey]).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    print(response.result.value!)
                    if (jsonObj["errCode"].int == 0) {
                        self.devicesList = TASensorList(listArray: jsonObj["items"])
                        success(jsonObj["items"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                        if (jsonObj["errCode"].int == -1) {
                            DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                            self.triggerLogOut()
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    
    // MARK:- Get Tracker List
    
    /**
     Get detail of specific Tracker of User from Server
     
     - Parameters:
     - sessonKey: session Key for Logged in User
     - trackerUUID: trackerUUID of the sensor
     - success: Success Block
     - failure: Faiure Block
     */
    public func getTrackerDetail(trackerUUID: String, success: SuccessHandler!, failure: ErrorHandler!) {
        var sessionKey = ""
        if let sessionK = UserDefaults.standard.string(forKey: AppConstants.sessionKeyForSignedUser) {
            sessionKey = sessionK
        }
        let trackerRegistrationUrl = String(format: "%@/tracker", AppConstants.BASEURL())
        DDLogVerbose("getting detail for sensorID \(trackerUUID) from  server | \(trackerRegistrationUrl)");
        networkManager.request(trackerRegistrationUrl, method: .get, parameters: nil, encoding: URLEncoding.default, headers: ["content-type" : "application/json", "sessionkey" : sessionKey]).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                print(response.result.value!)
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if (jsonObj["errCode"].int == 0) {
                        //self.devicesList = TASensorList(listArray: jsonObj["items"])
                        success(jsonObj["items"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                        if (jsonObj["errCode"].int == -1) {
                            DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                            self.triggerLogOut()
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    // MARK:- Delete Tracker
    
    /**
     Delete Specified Sensor from already registered Sensors
     
     - Parameters:
     - sensorDict: sensor Information that needs to be deleted
     - sessonKey: Session Key for Logged in User
     - success: Success Block
     - failure: Failure Block
     */
    public func deleteTracker(sensorDict:[String: Any], sessonKey:String!, success: SuccessHandler!, failure: ErrorHandler!) {
        
        let trackerRegistrationUrl = String(format: "%@/tracker", AppConstants.BASEURL())
        DDLogVerbose("Deleting linked sensorid | \(String(describing: sensorDict["UUID"]))");
        networkManager.request(trackerRegistrationUrl, method: .delete, parameters: sensorDict, encoding: JSONEncoding.prettyPrinted, headers: ["content-type" : "application/json", "sessionkey" : sessonKey]).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if (jsonObj["errCode"].int == 0) {
                        success(jsonObj)
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                        if (jsonObj["errCode"].int == -1) {
                            DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                            self.triggerLogOut()
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    // MARK:- Share & Unshare Tracker
    
    /**
     Share Tracker with another registered User of Panasonic Tracker
     
     - Parameters:
     - shareDict: Required Information to Share Sensor
     - success: Success Block
     - failure: Failure Block
     */
    public func shareTracker(shareDict: [String: Any], success: SuccessHandler!, failure: ErrorHandler!) {
        let shareTrackerUrl = String(format: "%@/shareTracker", AppConstants.BASEURL())
        var sessionKey = ""
        if let sessionK = UserDefaults.standard.string(forKey: AppConstants.sessionKeyForSignedUser) {
            sessionKey = sessionK
        }
        DDLogVerbose("Sending Sharing Tracker Request Using \(shareTrackerUrl)");
        networkManager.request(shareTrackerUrl, method: .put, parameters: shareDict, encoding: JSONEncoding.prettyPrinted, headers: ["content-type" : "application/json", "sessionkey" : sessionKey]).responseJSON(completionHandler: { (response) in
            
            if let err = response.result.error {
                print(response.result.error!)
                failure(err)
                
            } else {
                
                if (response.result.value != nil) {
                    print(response.result.value!)
                    let jsonObj = JSON(response.result.value!)
                    print(jsonObj)
                    if (jsonObj["errCode"].int == 0) {
                        success(jsonObj["data"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                        if (jsonObj["errCode"].int == -1) {
                            DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                            self.triggerLogOut()
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    /**
     Shared Tracker acknowledgement to Primary User of Panasonic Tracker
     
     - Parameters:
     - shareAckDict: UUID of Tracker | Response //0 for ACCEPT and 1 for REJECT.
     - success: Success Block
     - failure: Failure Block
     */
    public func sharedTrackerAck(shareAckDict: [String: Any], success: SuccessHandler!, failure: ErrorHandler!) {
        let sharedTrackerAckUrl = String(format: "%@/shareUser/acknowledgement", AppConstants.BASEURL())
        var sessionKey = ""
        if let sessionK = UserDefaults.standard.string(forKey: AppConstants.sessionKeyForSignedUser) {
            sessionKey = sessionK
        }
        //networkManager.retrier = RetryHandler()
        DDLogVerbose("Sending Shared Tracker acknowledgement to Primary User \(sharedTrackerAckUrl)");
        networkManager.request(sharedTrackerAckUrl, method: .post, parameters: shareAckDict, encoding: JSONEncoding.prettyPrinted, headers: ["content-type" : "application/json", "sessionkey" : sessionKey]).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if (jsonObj["errCode"].int == 0) {
                        success(jsonObj["data"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                        if (jsonObj["errCode"].int == -1) {
                            DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                            self.triggerLogOut()
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    /**
     Cancel Share/Unshare Tracker with another registered User of Panasonic Tracker
     
     - Parameters:
     - shareDict: Required Information to Share Sensor
     - success: Success Block
     - failure: Failure Block
     */
    public func unShareTracker(unshareDict: [String: Any], success: SuccessHandler!, failure: ErrorHandler!) {
        let unshareTrackerUrl = String(format: "%@/shareTracker", AppConstants.BASEURL())
        var sessionKey = ""
        if let sessionK = UserDefaults.standard.string(forKey: AppConstants.sessionKeyForSignedUser) {
            sessionKey = sessionK
        }
        DDLogVerbose("Requesting Cancel share/unshare Tracker Using \(unshareTrackerUrl)");
        networkManager.request(unshareTrackerUrl, method: .delete, parameters: unshareDict, encoding: JSONEncoding.prettyPrinted, headers: ["content-type" : "application/json", "sessionkey" : sessionKey]).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if (jsonObj["errCode"].int == 0) {
                        success(jsonObj["data"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                        if (jsonObj["errCode"].int == -1) {
                            DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                            self.triggerLogOut()
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    // MARK:- Switch Lost Notifications Turn ON/OFF
    
    /*
     Switch ON/OFF LOST MODE REMOTE NOTIFICATIONS
     0 for TURN OFF,
     1 for TURN ON,
     - Parameters:
     - lostSwitchDict: LOST MODE REMOTE NOTIFICATIONS TURN ON/OFF DICT
     - success: Success Block
     - failure: Failure Block
     */
    public func setLostNotificationMode(lostModeDict: [String: Any], success: SuccessHandler!, failure: ErrorHandler!) {
        let setLostModeUrl = String(format: "%@/notification/switch", AppConstants.BASEURL())
        var sessionKey = ""
        if let sessionK = UserDefaults.standard.string(forKey: AppConstants.sessionKeyForSignedUser) {
            sessionKey = sessionK
        }
        DDLogVerbose("Updating Switch Notifications Toggle Using \(setLostModeUrl)");
        networkManager.request(setLostModeUrl, method: .put, parameters: lostModeDict, encoding: JSONEncoding.prettyPrinted, headers: ["content-type" : "application/json", "sessionkey" : sessionKey]).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if (jsonObj["errCode"].int == 0) {
                        success(jsonObj["data"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                        if (jsonObj["errCode"].int == -1) {
                            DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                            self.triggerLogOut()
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    // MARK:- Update Tracker Status Lost, Disconnected, Found
    
    /*
     Update Lost Sensor Status to Server
     0 for disconnected,
     1 for connected,
     2 for lost,
     3 for found.
     - Parameters:
     - lostModeDict: Lost Mode Dictionary Information
     - success: Success Block
     - failure: Failure Block
     */
    public func setLostMode(lostModeDict: [String: Any], success: SuccessHandler!, failure: ErrorHandler!) {
        let setLostModeUrl = String(format: "%@/lostMode", AppConstants.BASEURL())
        var sessionKey = ""
        if let sessionK = UserDefaults.standard.string(forKey: AppConstants.sessionKeyForSignedUser) {
            sessionKey = sessionK
        }
        DDLogVerbose("Updating Tracker status Using \(setLostModeUrl)");
        networkManager.request(setLostModeUrl, method: .put, parameters: lostModeDict, encoding: JSONEncoding.prettyPrinted, headers: ["content-type" : "application/json", "sessionkey" : sessionKey]).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if (jsonObj["errCode"].int == 0) {
                        success(jsonObj["data"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                        if (jsonObj["errCode"].int == -1) {
                            DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                            self.triggerLogOut()
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    // MARK:- Update FDS Sensor Status to Web Server
    
    /*
     Update Fixed FDS Success State to Server
     - Parameters:
     - lostModeDict: Fix FDS Dictionary Information
     - success: Success Block
     - failure: Failure Block
     */
    public func updateFDSFixState(fdsDict: [String: Any], success: SuccessHandler!, failure: ErrorHandler!) {
        let updateFDSStateUrl = String(format: "%@/fdsError", AppConstants.BASEURL())
        var sessionKey = ""
        if let sessionK = UserDefaults.standard.string(forKey: AppConstants.sessionKeyForSignedUser) {
            sessionKey = sessionK
        }
        DDLogVerbose("Updating Fixed FDS Tracker status Using \(updateFDSStateUrl)");
        networkManager.request(updateFDSStateUrl, method: .post, parameters: fdsDict, encoding: JSONEncoding.prettyPrinted, headers: ["content-type" : "application/json", "sessionkey" : sessionKey]).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if (jsonObj["errCode"].int == 0) {
                        success(jsonObj["data"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                        if (jsonObj["errCode"].int == -1) {
                            DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                            self.triggerLogOut()
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    // MARK:- Update Tracker Location When it is in Lost Mode
    
    /*
     Update Tracker Location to Server When tracker is in Lost Mode
     - Parameters:
     - locationDict: location Dictionary Info
     - success: Success Block
     - failure: Failure Block
     */
    public func updateTrackerLocation(locationDict: [String: Any], success: @escaping SuccessHandler, failure: @escaping ErrorHandler) {
        let updateLocationUrl = String(format: "%@/trackerLocation", AppConstants.BASEURL())
        /*var sessionKey = ""
         if let sessionK = UserDefaults.standard.string(forKey: AppConstants.sessionKeyForSignedUser) {
         sessionKey = sessionK
         }*/
        print(locationDict)
        //DDLogVerbose("Updating Tracker location data Using \(updateLocationUrl)");
        networkManager.request(updateLocationUrl, method: .put, parameters: locationDict, encoding: JSONEncoding.prettyPrinted, headers: ["content-type" : "application/json"]).responseJSON(completionHandler: { (response) in //, "sessionkey" : sessionKey
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if (jsonObj["errCode"].int == 0) {
                        success(jsonObj["data"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                        if (jsonObj["errCode"].int == -1) {
                            DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                            self.triggerLogOut()
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    // MARK:- Retrieve Tracker History for Specific User
    
    /*
     Retrieve Tracker History for Specific User
     - Parameters:
     - success: Success Block
     - failure: Failure Block
     */
    public func retrieveShareTrackerHistory(success: SuccessHandler!, failure: ErrorHandler!) {
        let trackerHistoryUrl = String(format: "%@/shareTracker/history", AppConstants.BASEURL())
        var sessionKey = ""
        if let sessionK = UserDefaults.standard.string(forKey: AppConstants.sessionKeyForSignedUser) {
            sessionKey = sessionK
        }
        DDLogVerbose("Retrieving Tracker History for current logged in user using \(trackerHistoryUrl)");
        networkManager.request(trackerHistoryUrl, method: .get, parameters: nil, encoding: URLEncoding.default, headers: ["content-type" : "application/json", "sessionkey" : sessionKey]).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    print(jsonObj)
                    if (jsonObj["errCode"].int == 0) {
                        self.shareHistory = TAHistoryList(listArray: jsonObj["items"])
                        success(jsonObj["items"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                        if (jsonObj["errCode"].int == -1) {
                            DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                            self.triggerLogOut()
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    // MARK:- Retrieve Tracker's Last Known Location
    
    /*
     Retrieve Tracker From Server by primary or Secondary User
     - Parameters:
     - queryParamDict: Set Should show last location or not
     - success: Success Block
     - failure: Failure Block
     */
    public func retrieveTrackerLocation(queryParamDict: [String: Any], success: SuccessHandler!, failure: ErrorHandler!) {
        let UUID = queryParamDict["UUID"] as! String
        let retrieveLocationUrl = String(format: "%@/trackerLocation?UUID=%@&lastLocation=\(String(describing: queryParamDict["lastLocation"]!))", AppConstants.BASEURL(), UUID)
        var sessionKey = ""
        if let sessionK = UserDefaults.standard.string(forKey: AppConstants.sessionKeyForSignedUser) {
            sessionKey = sessionK
        }
        //DDLogVerbose("Retrieving Tracker last known location Using \(retrieveLocationUrl)");
        networkManager.request(retrieveLocationUrl, method: .get, parameters: nil, encoding: URLEncoding.default, headers: ["content-type" : "application/json", "sessionkey" : sessionKey]).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if (jsonObj["errCode"].int == 0) {
                        success(jsonObj["items"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                        if (jsonObj["errCode"].int == -1) {
                            DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                            self.triggerLogOut()
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    // MARK:- Upload Tracker's Image To Server
    /*
     /// - Parameters:
     ///   - filePath: filePath for the Tracker Image that needs to be uploaded
     ///   - success: success response -> Gives Public URL for uploaded tracker Image
     ///   - failure: failure response -> Gives Error due to which upload failed
     */
    
    public func uploadTrackerImage(filePath:URL, success: SuccessHandler!, failure: ErrorHandler!) {
        
        if let imageData = try? Data(contentsOf: filePath) {
            let MD5Hash = imageData.md5
            let uploadUserImageURL = String(format: "%@/tracker/uploadFile?md5=%@&uploadFile=%@", AppConstants.BASEURL(), MD5Hash, filePath.absoluteString)
            var sessionKey = ""
            if let sessionK = UserDefaults.standard.string(forKey: AppConstants.sessionKeyForSignedUser) {
                sessionKey = sessionK
            }
            DDLogVerbose("Uploading User Image to Server \(uploadUserImageURL)")
            networkManager.upload(multipartFormData: { multipartFormData in
                multipartFormData.append(imageData, withName: "trackerImage", fileName: filePath.absoluteString, mimeType: "image/png")
                multipartFormData.append(filePath, withName: "uploadFile")
            },usingThreshold: UInt64.init(), to: uploadUserImageURL, method: .post, headers: ["Content-type": "multipart/form-data", "sessionkey" : sessionKey], encodingCompletion: { encodingResult in
                switch encodingResult {
                case .success(let upload, _, _):
                    upload.responseJSON(completionHandler: { response in
                        DDLogVerbose("Image response - \(response)")
                        if let err = response.result.error {
                            failure(err)
                        } else {
                            if (response.result.value != nil) {
                                let jsonObj = JSON(response.result.value!)
                                if (jsonObj["errCode"].int == 0) {
                                    success(jsonObj["data"])
                                } else {
                                    if let errorMessage = jsonObj["errMessage"].string {
                                        DDLogVerbose(errorMessage)
                                        let error = errorMessage.errorDescription
                                        failure(error)
                                    }
                                    if (jsonObj["errCode"].int == -1) {
                                        DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                                        self.triggerLogOut()
                                    }
                                }
                            } else {
                                // Handle Nil
                                failure(nil)
                            }
                        }
                    })
                case .failure(let encodingError):
                    print(encodingError)
                    failure(nil)
                }
            })
        }
    }
    
    // MARK:- Upload User's Image To Server
    /*
     /// - Parameters:
     ///   - filePath: filePath for the User Image that needs to be uploaded
     ///   - success: success response -> Gives Public URL for uploaded User Image
     ///   - failure: failure response -> Gives Error due to which upload failed
     */
    
    public func uploadUserImage(filePath:URL, success: SuccessHandler!, failure: ErrorHandler!) {
        
        if let imageData = try? Data(contentsOf: filePath) {
            let MD5Hash = imageData.md5
            let uploadUserImageURL = String(format: "%@/user/uploadFile?md5=%@&uploadFile=%@", AppConstants.BASEURL(), MD5Hash, filePath.absoluteString)
            var sessionKey = ""
            if let sessionK = UserDefaults.standard.string(forKey: AppConstants.sessionKeyForSignedUser) {
                sessionKey = sessionK
            }
            DDLogVerbose("Uploading User Image to Server \(uploadUserImageURL)")
            networkManager.upload(multipartFormData: { multipartFormData in
                multipartFormData.append(imageData, withName: "userImage", fileName: filePath.absoluteString, mimeType: "image/png")
                multipartFormData.append(filePath, withName: "uploadFile")
            }, usingThreshold: UInt64.init(), to: uploadUserImageURL, method: .post, headers: ["Content-type": "multipart/form-data", "sessionkey" : sessionKey], encodingCompletion: { encodingResult in
                switch encodingResult {
                case .success(let upload, _, _):
                    upload.responseJSON(completionHandler: { response in
                        DDLogVerbose("Image response - \(response)")
                        if let err = response.result.error {
                            failure(err)
                        } else {
                            if (response.result.value != nil) {
                                let jsonObj = JSON(response.result.value!)
                                if (jsonObj["errCode"].int == 0) {
                                    success(jsonObj["data"])
                                } else {
                                    if let errorMessage = jsonObj["errMessage"].string {
                                        DDLogVerbose(errorMessage)
                                        let error = errorMessage.errorDescription
                                        failure(error)
                                    }
                                    if (jsonObj["errCode"].int == -1) {
                                        DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                                        self.triggerLogOut()
                                    }
                                }
                            } else {
                                // Handle Nil
                                failure(nil)
                            }
                        }
                    })
                case .failure(let encodingError):
                    print(encodingError)
                    failure(nil)
                }
            })
        }
    }
    
    // MARK:- Upload Tracker Custom Recorded Ringtone To Server
    /*
     /// - Parameters:
     ///   - filePath: filePath for the User Image that needs to be uploaded
     ///   - success: success response -> Gives Public URL for uploaded User Image
     ///   - failure: failure response -> Gives Error due to which upload failed
     */
    
    public func uploadTrackerRingtone(filePath:String, success: SuccessHandler!, failure: ErrorHandler!) {
        
        let url:URL = URL.init(fileURLWithPath: filePath)
        if let audioData = try? Data(contentsOf: url) {
            let MD5Hash = audioData.md5
            let uploadTrackerAudioURL = String(format: "%@/tracker/ringTone?md5=%@&uploadFile=%@", AppConstants.BASEURL(), MD5Hash, url.absoluteString)
            var sessionKey = ""
            if let sessionK = UserDefaults.standard.string(forKey: AppConstants.sessionKeyForSignedUser) {
                sessionKey = sessionK
            }
            DDLogVerbose("Uploading Tracker Audio to Server \(uploadTrackerAudioURL)")
            networkManager.upload(multipartFormData: { multipartFormData in
                multipartFormData.append(audioData, withName: "trackerAudio", fileName: url.absoluteString, mimeType: "audio/mpeg3")
                multipartFormData.append(url, withName: "uploadFile")
            }, usingThreshold: UInt64.init(), to: uploadTrackerAudioURL, method: .post, headers: ["Content-type": "multipart/form-data", "sessionkey" : sessionKey], encodingCompletion: { encodingResult in
                switch encodingResult {
                case .success(let upload, _, _):
                    upload.responseJSON(completionHandler: { response in
                        DDLogVerbose("Audio Upload Response - \(response)")
                        if let err = response.result.error {
                            failure(err)
                        } else {
                            if (response.result.value != nil) {
                                let jsonObj = JSON(response.result.value!)
                                if (jsonObj["errCode"].int == 0) {
                                    success(jsonObj["data"])
                                } else {
                                    if let errorMessage = jsonObj["errMessage"].string {
                                        DDLogVerbose(errorMessage)
                                        let error = errorMessage.errorDescription
                                        failure(error)
                                    }
                                    if (jsonObj["errCode"].int == -1) {
                                        DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                                        self.triggerLogOut()
                                    }
                                }
                            } else {
                                // Handle Nil
                                failure(nil)
                            }
                        }
                    })
                case .failure(let encodingError):
                    print(encodingError)
                    failure(nil)
                }
            })
        } else {
            failure(nil)
        }
    }
    
    public func downloadImageFrom(imageUrl:String, success: ImageHandler!) {
        
        let imageURL = URL.init(string: imageUrl)!
        networkManager.request(imageURL).responseImage(completionHandler: { response in
            if let image = response.result.value {
                print("image downloaded: \(image)")
                success(image)
            }
        })
    }
    
    func getAbsoulutePath(ringTonePath: String) -> String {
        
        let fileManager = FileManager.default
        if let tDocumentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let filePath =  tDocumentDirectory.appendingPathComponent("\(ringTonePath)")
            if !fileManager.fileExists(atPath: filePath.path) {
                do {
                    try fileManager.createDirectory(atPath: filePath.path, withIntermediateDirectories: false, attributes: nil)
                } catch {
                    NSLog("Couldn't create document directory")
                }
            }
            NSLog("Document directory is \(filePath)")
            return filePath.relativePath
        }
        return ""
    }
    
    public func installNewRingTones() {
        DDLogVerbose("installNewRingTones called")
        let extractPath = self.getAbsoulutePath(ringTonePath: "ringtones")
        DDLogVerbose("Create RingTone Directory at Path :- \(extractPath)")
        if let ringCount = listFilesFromDocumentsFolder(), ringCount.count == 0 {
            DDLogVerbose("No Ringtones were downloaded. Downloading ringtones...")
            let timestamp = Date().timeIntervalSince1970
            SLCloudConnector.sharedInstance.downloadRingTones(timeStamp: String(timestamp), success: { [weak self] (successDic) in
                guard let strongSelf = self else { return }
                DDLogVerbose("*********************************************")
                DDLogVerbose("More RingTones are available now. Ringtone Download is complete")
                DDLogVerbose("*********************************************")
                strongSelf.getDNDSettings()
            }) { (failureDict) in
                DDLogVerbose("RingTone Download Failed \(String(describing: failureDict?.localizedDescription))")
            }
        }
    }
    
    public func getLatestFirmwareInfo() {
        
        self.getLatestFirmwareInfo(success: { (successDic) in
            DDLogVerbose("Latest Firmware Info Retrieved..")
            if !self.firmwareAlreadyDownloaded() {
                SLCloudConnector.sharedInstance.downloadDFUZip(success: { (successDic) in
                    DDLogVerbose("Firmware Download \(self.latestFirmwareVersion) success => ")
                }) { (failureDict) in
                    DDLogVerbose("Firmware Download Failed \(String(describing: failureDict?.localizedDescription))")
                }
            }
        }) { (failureDict) in
            DDLogVerbose("Firmware Download Failed \(String(describing: failureDict?.localizedDescription))")
        }
    }
    
    func downloadTestFirmware() {
        DDLogVerbose("Donnload Test FIrmware called")
        let extractPath = self.getAbsoulutePath(ringTonePath: "firmware")
        DDLogVerbose("Create FIrmware Directory at Path :- \(extractPath)")
        if let firmwareCount = listFirmwareFromDocumentsFolder(), firmwareCount.count == 0 {
            DDLogVerbose("No FIrmware was downloaded. Downloading...")
            self.downloadDFUZip(success: { (successDic) in
                DDLogVerbose("More Firmware are available now. Firmware Download is complete")
            }) { (failureDict) in
                DDLogVerbose("FIrmware Download Failed \(String(describing: failureDict?.localizedDescription))")
            }
        }
    }
    
    public func firmwareAlreadyDownloaded() -> Bool  {
        let url = SLCloudConnector.getDocumentDirectory().appendingPathComponent("\(latestFirmwareVersion).zip", isDirectory: false)
        if !FileManager.default.fileExists(atPath: url.path) {
            DDLogVerbose("File not found at path \(url.path)")
            return false
        }
        return true
    }
    
    public func getFirmwarePath() -> URL {
        return SLCloudConnector.getDocumentDirectory().appendingPathComponent("\(latestFirmwareVersion).zip", isDirectory: false)
    }
    // get Document Directory
    static func getDocumentDirectory () -> URL {
        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            return url
        }else{
            fatalError("Unable to access document directory")
        }
    }
    
    /// Controls if Lost Location Update will be recieved OR NOT
    ///
    /// - Parameter isEnabled: Enabled OR DISABLE SWITCH FOR LOST LOCATION UPDATES IN BACKGROUND iOS
    func enableDisableLostNotifications(isEnabled: Bool) {
        
        var updateDict: [String: Any] = [:]
        updateDict["notificationFlag"] = isEnabled ? 1 : 0
        setLostNotificationMode(lostModeDict: updateDict, success: { (successDict) in
            DispatchQueue.main.async {
                DDLogVerbose("Update Switch Lost Notification Mode isEnabled \(isEnabled ? "YES" : "NO") -> Success ")
            }
        }) { (errorDict) in
            DispatchQueue.main.async {
                DDLogVerbose("Update Switch Lost Notification Mode isEnabled \(isEnabled ? "YES" : "NO") -> Failed -> \(String(describing: errorDict?.localizedDescription))")
            }
        }
    }
    
    public func listFilesFromDocumentsFolder() -> [String]? {
        DDLogVerbose("Retrieving number of downloaded ringtones...")
        let fileMngr = FileManager.default
        
        // Full path to documents directory
        let dirPaths = fileMngr.urls(for: .documentDirectory, in: .userDomainMask)
        let docsDir = dirPaths[0]
        let filePath =  docsDir.appendingPathComponent("ringtones").relativePath
        
        // List all contents of directory and return as [String] OR nil if failed
        return try? fileMngr.contentsOfDirectory(atPath:filePath)
    }
    
    public func listFirmwareFromDocumentsFolder() -> [String]? {
        DDLogVerbose("Retrieving number of downloaded ringtones...")
        let fileMngr = FileManager.default
        
        // Full path to documents directory
        let dirPaths = fileMngr.urls(for: .documentDirectory, in: .userDomainMask)
        let docsDir = dirPaths[0]
        let filePath =  docsDir.appendingPathComponent("firmware").relativePath
        
        // List all contents of directory and return as [String] OR nil if failed
        return try? fileMngr.contentsOfDirectory(atPath:filePath)
    }
    
    func markDirectionsOnMap(originLat:String, originLong:String, destinationLat:String, destinationLong:String, success: SuccessHandler!) {
        
        let APIKey = "AIzaSyABMxBdDrJs3FlpQRHkXucFFvgzNCjdLmE"
        let directionURL = "https://maps.googleapis.com/maps/api/directions/json?" +
            "origin=\(originLat),\(originLong)&destination=\(destinationLat),\(destinationLong)&" +
            "key=\(APIKey)".urlEncoded
        Alamofire.request(directionURL).responseJSON { response in
            do {
                let json = try JSON(data: response.data!)
                success(json)
            }
            catch let error {
                print(error.localizedDescription)
            }
        }
    }
    
    // MARK:- DND Settings
    
    /**
     Get DND Settings From Server.
     /// - Parameters:
     ///   - success: Success Block
     ///   - failure: Failure Block
     */
    
    public func getDNDSettings(success: SuccessHandler!, failure: ErrorHandler!) {
        
        let getDNDSettingsUrl = String(format: "%@/dnd", AppConstants.BASEURL())
        var sessonKey = ""
        if let sessionK = UserDefaults.standard.string(forKey: AppConstants.sessionKeyForSignedUser) {
            sessonKey = sessionK
        }
        DDLogVerbose("getDNDSettings called \(getDNDSettingsUrl)");
        networkManager.request(getDNDSettingsUrl, method: .get, parameters: nil, encoding: URLEncoding.default, headers: ["content-type" : "application/json", "sessionkey" : sessonKey]).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if (jsonObj["errCode"].int == 0) {
                        self.sleeptime = TASleepModel(sleepDict: JSON(jsonObj["data"]))
                        success(jsonObj["data"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    /**
     Put New time Settigns for DND on Server.
     /// - Parameters:
     ///   - dndDict: Dictionary info for DND that needs to be added
     ///   - success: Success Block
     ///   - failure: Failure Block
     */
    
    public func setDNDSettings(dndDict: [String: Any], success: SuccessHandler!, failure: ErrorHandler!) {
        
        let setDNDUrl = String(format: "%@/dnd", AppConstants.BASEURL())
        var sessonKey = ""
        if let sessionK = UserDefaults.standard.string(forKey: AppConstants.sessionKeyForSignedUser) {
            sessonKey = sessionK
        }
        
        DDLogVerbose("setDNDSettings called \(setDNDUrl)");
        networkManager.request(setDNDUrl, method: .put, parameters: dndDict, encoding: JSONEncoding.prettyPrinted, headers: ["content-type" : "application/json", "sessionkey" : sessonKey]).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                
                print(response.result.value!)
                
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if (jsonObj["errCode"].int == 0) {
                        self.sleeptime = TASleepModel(sleepDict: JSON(jsonObj["data"]))
                        success(jsonObj["data"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    /**
     Send Test DFU Update Notification from Server
     /// - Parameters:
     ///   - success: Success Block
     ///   - failure: Failure Block
     */
    
    internal func sendTestDFUNotification(success: SuccessHandler!, failure: ErrorHandler!) {
        
        guard let userEmail = userProfile?.emailId else {
            return
        }
        let sendTestDFUNotifyUrl = String(format: "https://13.59.36.23:5000/firmwareUpdateNotification?userName=\(userEmail)")
        
        DDLogVerbose("sendTestDFUNotification called \(sendTestDFUNotifyUrl)");
        networkManager.request(sendTestDFUNotifyUrl, method: .get, parameters: nil, encoding: JSONEncoding.prettyPrinted, headers: ["content-type" : "application/json"]).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                
                print(response.result.value!)
                
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if (jsonObj["errCode"].int == 0) {
                        success(jsonObj["data"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    // MARK:- Wifi SafeZone API's
    
    /**
     Register a New Wi-Fi Safe Zone on Server.
     /// - Parameters:
     ///   - wifiDict: Dictionary info for Wifi that needs to be added
     ///   - success: Success Block
     ///   - failure: Failure Block
     */
    
    public func addWifiForSafeZone(wifiDict: [String: Any], success: SuccessHandler!, failure: ErrorHandler!) {
        
        let addWifiForSafeZoneUrl = String(format: "%@/wifiZone", AppConstants.BASEURL())
        var sessonKey = ""
        if let sessionK = UserDefaults.standard.string(forKey: AppConstants.sessionKeyForSignedUser) {
            sessonKey = sessionK
        }
        DDLogVerbose("addWifiForSafeZone called \(addWifiForSafeZoneUrl)");
        networkManager.request(addWifiForSafeZoneUrl, method: .put, parameters: wifiDict, encoding: JSONEncoding.prettyPrinted, headers: ["content-type" : "application/json", "sessionkey" : sessonKey]).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if (jsonObj["errCode"].int == 0) {
                        success(jsonObj["data"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                        if (jsonObj["errCode"].int == -1) {
                            DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                            self.triggerLogOut()
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    /**
     Get List of Wi-Fi Registered for Safe Zone on Server.
     /// - Parameters:
     ///   - success: Success Block
     ///   - failure: Failure Block
     */
    
    public func getWifiListForSafeZone(success: SuccessHandler!, failure: ErrorHandler!) {
        
        let getWifiForSafeZoneUrl = String(format: "%@/wifiZone", AppConstants.BASEURL())
        var sessonKey = ""
        if let sessionK = UserDefaults.standard.string(forKey: AppConstants.sessionKeyForSignedUser) {
            sessonKey = sessionK
        }
        DDLogVerbose("getWifiListForSafeZone called \(getWifiForSafeZoneUrl)");
        networkManager.request(getWifiForSafeZoneUrl, method: .get, parameters: nil, encoding: URLEncoding.default, headers: ["content-type" : "application/json", "sessionkey" : sessonKey]).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if (jsonObj["errCode"].int == 0) {
                        //self.wifiList = TAWifiList(listArray: JSON(jsonObj["items"]))
                        success(jsonObj["data"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                        if (jsonObj["errCode"].int == -1) {
                            DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                            self.triggerLogOut()
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    /**
     Delete any Specific Wi-Fi Registered for Safe Zone on Server.
     /// - Parameters:
     ///   - wifiDict: Dictionary info for Wifi that needs to be deleted
     ///   - success: Success Block
     ///   - failure: Failure Block
     */
    
    public func deleteWifiForSafeZone(bssid: String, success: SuccessHandler!, failure: ErrorHandler!) {
        
        let deleteWifiForSafeZoneUrl = String(format: "%@/wifiZone?bssid=\(bssid)".urlEncoded, AppConstants.BASEURL())
        var sessonKey = ""
        if let sessionK = UserDefaults.standard.string(forKey: AppConstants.sessionKeyForSignedUser) {
            sessonKey = sessionK
        }
        DDLogVerbose("deleteWifiForSafeZoneUrl called \(deleteWifiForSafeZone)");
        networkManager.request(deleteWifiForSafeZoneUrl, method: .delete, parameters: nil, encoding: JSONEncoding.prettyPrinted, headers: ["content-type" : "application/json", "sessionkey" : sessonKey]).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if (jsonObj["errCode"].int == 0) {
                        success(jsonObj["data"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                        if (jsonObj["errCode"].int == -1) {
                            DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                            self.triggerLogOut()
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    /**
     Add New Contact for SOS Feature on Server.
     /// - Parameters:
     ///   - addDict: Dictionary info Contact be to added
     ///   - success: Success Block
     ///   - failure: Failure Block
     */
    
    public func addContactForSOS(addDict: [String: Any], success: SuccessHandler!, failure: ErrorHandler!) {
        
        let addContactForSOSUrl = String(format: "%@/sosContact", AppConstants.BASEURL())
        var sessonKey = ""
        if let sessionK = UserDefaults.standard.string(forKey: AppConstants.sessionKeyForSignedUser) {
            sessonKey = sessionK
        }
        DDLogVerbose("addContactForSOS called \(addContactForSOSUrl)");
        networkManager.request(addContactForSOSUrl, method: .put, parameters: addDict, encoding: JSONEncoding.prettyPrinted, headers: ["content-type" : "application/json", "sessionkey" : sessonKey]).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if (jsonObj["errCode"].int == 0) {
                        success(jsonObj["data"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                        if (jsonObj["errCode"].int == -1) {
                            DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                            self.triggerLogOut()
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    /**
     Delete Exiting SOS Contact for SOS Feature on Server.
     /// - Parameters:
     ///   - phoneNumber: Contact Number to be deleted
     ///   - success: Success Block
     ///   - failure: Failure Block
     */
    
    public func deleteContactForSOS(phoneNumber: String!, success: SuccessHandler!, failure: ErrorHandler!) {
        
        let deleteContactForSOSUrl = String(format: "%@/sosContact?contactNumber=\(phoneNumber!)", AppConstants.BASEURL())
        var sessonKey = ""
        if let sessionK = UserDefaults.standard.string(forKey: AppConstants.sessionKeyForSignedUser) {
            sessonKey = sessionK
        }
        DDLogVerbose("deleteContactForSOS called \(deleteContactForSOSUrl)");
        networkManager.request(deleteContactForSOSUrl, method: .delete, parameters: nil, encoding: JSONEncoding.prettyPrinted, headers: ["content-type" : "application/json", "sessionkey" : sessonKey]).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if (jsonObj["errCode"].int == 0) {
                        success(jsonObj["data"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                        if (jsonObj["errCode"].int == -1) {
                            DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                            self.triggerLogOut()
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    /**
     Get List of SOS Contacts for SOS Feature on Server.
     /// - Parameters:
     ///   - success: Success Block
     ///   - failure: Failure Block
     */
    
    public func getContactsForSOS(success: SuccessHandler!, failure: ErrorHandler!) {
        
        let getContactsForSOSUrl = String(format: "%@/sosContact", AppConstants.BASEURL())
        var sessonKey = ""
        if let sessionK = UserDefaults.standard.string(forKey: AppConstants.sessionKeyForSignedUser) {
            sessonKey = sessionK
        }
        DDLogVerbose("getContactsForSOS called \(getContactsForSOSUrl)");
        networkManager.request(getContactsForSOSUrl, method: .get, parameters: nil, encoding: URLEncoding.default, headers: ["content-type" : "application/json", "sessionkey" : sessonKey]).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if (jsonObj["errCode"].int == 0) {
                        self.sosContacts = TAContactList(listArray: JSON(jsonObj["items"]))
                        success(jsonObj["items"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                        if (jsonObj["errCode"].int == -1) {
                            DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                            self.triggerLogOut()
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    /**
     Send SOS Alert to all SOS Contacts via server
     /// - Parameters:
     ///   - success: Success Block
     ///   - failure: Failure Block
     */
    
    public func sendSOSAlert(sosDict: [String: Any], success: SuccessHandler!, failure: ErrorHandler!) {
        
        let sendSOSAlertUrl = String(format: "%@/sos/message", AppConstants.BASEURL())
        var sessonKey = ""
        if let sessionK = UserDefaults.standard.string(forKey: AppConstants.sessionKeyForSignedUser) {
            sessonKey = sessionK
        }
        DDLogVerbose("sendSOSAlert called \(sendSOSAlertUrl)");
        networkManager.request(sendSOSAlertUrl, method: .post, parameters: sosDict, encoding: JSONEncoding.prettyPrinted, headers: ["content-type" : "application/json", "sessionkey" : sessonKey]).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if (jsonObj["errCode"].int == 0) {
                        success(jsonObj["data"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                        if (jsonObj["errCode"].int == -1) {
                            DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                            self.triggerLogOut()
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    /**
     Check Password to Disable SOS
     /// - Parameters: Password Dictionary
     ///   - success: Success Block
     ///   - failure: Failure Block
     */
    
    public func checkPassword(passwordDict: [String: Any], success: SuccessHandler!, failure: ErrorHandler!) {
        
        let checkPasswordUrl = String(format: "%@/isPassword", AppConstants.BASEURL())
        var sessonKey = ""
        if let sessionK = UserDefaults.standard.string(forKey: AppConstants.sessionKeyForSignedUser) {
            sessonKey = sessionK
        }
        DDLogVerbose("checkPassword called \(checkPasswordUrl)");
        networkManager.request(checkPasswordUrl, method: .put, parameters: passwordDict, encoding: JSONEncoding.prettyPrinted, headers: ["content-type" : "application/json", "sessionkey" : sessonKey]).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if (jsonObj["errCode"].int == 0) {
                        success(jsonObj["data"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                        if (jsonObj["errCode"].int == -1) {
                            DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                            self.triggerLogOut()
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    /**
     Buzz a Remote Mobile Phone
     /// - Parameters: Phone Dictionary with Phone Unique ID parameter.
     ///   - success: Success Block
     ///   - failure: Failure Block
     */
    
    public func buzzMobilePhone(phoneDict: [String: Any], success: SuccessHandler!, failure: ErrorHandler!) {
        
        let buzzMobilePhoneUrl = String(format: "%@/tracker/notification", AppConstants.BASEURL())
        var sessonKey = ""
        if let sessionK = UserDefaults.standard.string(forKey: AppConstants.sessionKeyForSignedUser) {
            sessonKey = sessionK
        }
        DDLogVerbose("buzzMobilePhone called \(buzzMobilePhoneUrl)");
        networkManager.request(buzzMobilePhoneUrl, method: .post, parameters: phoneDict, encoding: JSONEncoding.prettyPrinted, headers: ["content-type" : "application/json", "sessionkey" : sessonKey]).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if (jsonObj["errCode"].int == 0) {
                        success(jsonObj["data"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                        if (jsonObj["errCode"].int == -1) {
                            DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                            self.triggerLogOut()
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    /**
     Update logs to Server
     /// - Parameters: Tracker Stats Parameter Dictionary
     ///   - success: Success Block
     ///   - failure: Failure Block
     */
    
    public func updateLogs(statsDict: [String: Any], success: SuccessHandler!, failure: ErrorHandler!) {
        
        let updateLogsUrl = String(format: "%@/tracker/logs", AppConstants.BASEURL())
        var sessonKey = ""
        if let sessionK = UserDefaults.standard.string(forKey: AppConstants.sessionKeyForSignedUser) {
            sessonKey = sessionK
        }
        DDLogVerbose("updateLogs called \(updateLogsUrl)");
        networkManager.request(updateLogsUrl, method: .post, parameters: statsDict, encoding: JSONEncoding.prettyPrinted, headers: ["content-type" : "application/json", "sessionkey" : sessonKey]).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if (jsonObj["errCode"].int == 0) {
                        success(jsonObj["data"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                        if (jsonObj["errCode"].int == -1) {
                            DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                            self.triggerLogOut()
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    /**
     Raise A Ticket for Diag Tool Issue
     /// - Parameters: Manadatory Tracker Paramters
     ///   - success: Success Block
     ///   - failure: Failure Block
     */
    
    public func raiseTicket(ticketDict: [String: Any], success: SuccessHandler!, failure: ErrorHandler!) {
        
        let raiseTicketsUrl = String(format: "%@/tracker/raiseTicket", AppConstants.BASEURL())
        var sessonKey = ""
        if let sessionK = UserDefaults.standard.string(forKey: AppConstants.sessionKeyForSignedUser) {
            sessonKey = sessionK
        }
        DDLogVerbose("raiseTicket called \(raiseTicketsUrl)");
        networkManager.request(raiseTicketsUrl, method: .post, parameters: ticketDict, encoding: JSONEncoding.prettyPrinted, headers: ["content-type" : "application/json", "sessionkey" : sessonKey]).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if (jsonObj["errCode"].int == 0) {
                        success(jsonObj["data"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                        if (jsonObj["errCode"].int == -1) {
                            DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                            self.triggerLogOut()
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    
    public func generatedApiKey(success: SuccessHandler!, failure: ErrorHandler!) {
        
        DDLogVerbose("\(#function) Generated Api Key ############\n")
        var dict: [String: Any] = [:]
        dict["ThirdPartyID"] = "32LP1D"
        let customLoginUrl = String(format: "%@/ServiceRequest/generateApiKey", AppConstants.ServifyBASEURL)
        DDLogVerbose("requesting Api key with \(customLoginUrl)");
        
        networkManager.request(customLoginUrl, method: .post, parameters: dict, encoding: JSONEncoding.prettyPrinted, headers: AppConstants.contentType).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if (jsonObj["success"].boolValue == true) {
                        if let servifySessionKey = jsonObj["data"]["ApiKey"].string {
                            UserDefaults.standard.set(servifySessionKey, forKey: AppConstants.servifySessionKeyForSignedUser)
                            UserDefaults.standard.synchronize()
                        }
                        success(jsonObj["data"])
                    } else {
                        if let errorCode = jsonObj["status"].int {
                            if errorCode == 401 {
                                DDLogVerbose("Unauthorised")
                                failure("Unauthorised")
                            } else if errorCode == 444 {
                                DDLogVerbose("Insufficient Parameters")
                                failure("Insufficient Parameters")
                            } else if errorCode == 445 {
                                DDLogVerbose("System Error")
                                failure("System Error")
                            }
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    
    
    /**
     Get List of Tickets Raised on Server.
     /// - Parameters:
     ///   - success: Success Block
     ///   - failure: Failure Block
     */
    
    public func getRaisedTickets(success: SuccessHandler!, failure: ErrorHandler!) {
        
        let getRaisedTicketsUrl = String(format: "%@/ServiceRequest/getServiceHistory", AppConstants.ServifyBASEURL)
        var servifySessionKey = ""
        if let servifySessionK = UserDefaults.standard.string(forKey: AppConstants.servifySessionKeyForSignedUser) {
            servifySessionKey = servifySessionK
        }
        
        var dict: [String: String] = [:]
        dict["ThirdPartyID"] = "32LP1D"
        if let userId = self.userProfile?.userId {
            dict["ConsumerID"] = userId.stringValue
        } else if let userId = UserDefaults.standard.string(forKey: AppConstants.userIDKey) {
            dict["ConsumerID"] = userId
        }
        let header = ["Content-Type" : "application/json", "authorization" : servifySessionKey]
        DDLogVerbose("getRaisedTickets called \(getRaisedTicketsUrl) headers:\(header) parameters:\(dict)");
        let request = networkManager.request(getRaisedTicketsUrl, method: .post, parameters: dict, encoding: JSONEncoding.prettyPrinted, headers: ["content-type" : "application/json", "authorization" : servifySessionKey]).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if (jsonObj["sucess"].boolValue == true) {
                        self.raiseTickets = TARaiseTicketList(listArray: JSON(jsonObj["data"]))
                        success(jsonObj["items"])
                    } else {
                        if let errorMessage = jsonObj["msg"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                        if (jsonObj["errCode"].int == -1) {
                            DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                            self.triggerLogOut()
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
    
    public func getDNDSettings(completion: @escaping (() -> Void) = {} ) {
        
        SLCloudConnector.sharedInstance.getDNDSettings(success: { successResonse in
            completion()
            print("DND Settings Retrieved Successfully")
            if SLSensorManager.sharedInstance.isSleepModeActivated() {
                print("JitTest : Sleep Time Active")
            } else {
                print("JitTest : Sleep Time Disabled")
            }
        }) { errorDict in
            completion()
            if let errorMessage = errorDict?.localizedDescription, errorMessage != AppConstants.sslError {
                //self.showError(message: errorMessage)
            } else {
                //self.showError(message: AppConstants.offlineMessage)
            }
        }
    }
    
    public func retrieveAudio(for audioUrl: String) {
        
        let fileUrl = self.getSaveFileUrl(fileName: audioUrl)
        let destination: DownloadRequest.DownloadFileDestination = { _, _ in
            return (fileUrl, [.removePreviousFile, .createIntermediateDirectories])
        }
        networkManager.download(audioUrl, to:destination)
            .downloadProgress { (progress) in
                //self.progressLabel.text = (String)(progress.fractionCompleted)
                let _ = (String)(progress.fractionCompleted)
            }
            .responseData { (data) in
                //self.progressLabel.text = "Completed!"
                print("Audio Download Complete")
                if let url = data.destinationURL {
                    //print(url.absoluteString)
                    //print(url.relativePath)
                    
                    let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let toURL = documentsDirectory.appendingPathComponent(url.lastPathComponent.replacingOccurrences(of: "mp3", with: "m4a"))
                    
                    print("renaming file \(url.absoluteString) to \(toURL) url \(url.absoluteString.replacingOccurrences(of: "mp3", with: "m4a"))")
                    
                    do {
                        try FileManager.default.moveItem(at: url, to: toURL)
                        SLAudioPlayer.sharedInstance.tempURL = toURL
                        
                    } catch {
                        print(error.localizedDescription)
                        print("error renaming recording")
                    }
                }
        }
    }
    
    func getSaveFileUrl(fileName: String) -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let nameUrl = URL(string: fileName)
        let fileURL = documentsURL.appendingPathComponent((nameUrl?.lastPathComponent)!)
        NSLog(fileURL.absoluteString)
        return fileURL
    }
    
    public func getUUIDFor(serialNumber: String, success: SuccessHandler!, failure: ErrorHandler!) {
        
        var parameterdict:[String:Any] = [:]
        parameterdict["serialNumber"] = serialNumber
        
        let getUUIDForSerialNumberUrl = String(format: "%@/tracker/checkSerialNumber", AppConstants.BASEURL())
        var sessonKey = ""
        
        if let sessionK = UserDefaults.standard.string(forKey: AppConstants.sessionKeyForSignedUser) {
            sessonKey = sessionK
        }
        
        DDLogVerbose("getUUIDForSerialNumber called \(getUUIDForSerialNumberUrl)");
        networkManager.request(getUUIDForSerialNumberUrl, method: .get, parameters: parameterdict, encoding: URLEncoding.default, headers: ["content-type" : "application/json", "sessionkey" : sessonKey]).responseJSON(completionHandler: { (response) in
            if let err = response.result.error {
                failure(err)
            } else {
                if (response.result.value != nil) {
                    let jsonObj = JSON(response.result.value!)
                    if (jsonObj["errCode"].int == 0) {
                        self.uuidObj = TAUUIDModel(uuidDict: JSON(jsonObj["data"]))
                        success(jsonObj["items"])
                    } else {
                        if let errorMessage = jsonObj["errMessage"].string {
                            DDLogVerbose(errorMessage)
                            let error = errorMessage.errorDescription
                            failure(error)
                        }
                        if (jsonObj["errCode"].int == -1) {
                            DDLogVerbose("Session Expired!!!. Trigger LogOut...")
                            self.triggerLogOut()
                        }
                    }
                } else {
                    // Handle Nil
                    failure(nil)
                }
            }
        })
    }
    
}
