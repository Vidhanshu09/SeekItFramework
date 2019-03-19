//
//  TAUserProfileModel.swift
//  SeekLib
//
//  Created by Jitendra Chamoli on 09/10/18.
//

import Foundation
import SwiftyJSON

public class TAUserLoginData : NSObject {
    public var userId : String!
    public var password: String!
    public var pushToken: String!
}

public class TAUserProfileModel: NSObject {
    
    public var emailId: String?
    public var phoneNumber: String?
    public var countryCode: String?
    public var ringToneName: String?
    public var userId: NSNumber?
    public var firstName : String?
    public var lastName : String?
    public var pictureUrl: String?
    public var alertMode: NSNumber?
    public var isPasswordSet: NSNumber?
    public var sessionKey: String?
    public var loginType: LoginType?
    
    public override init() {
    }
    
    required public init (userData: JSON) {
        
        let user:UserProfileInfo = UserProfileInfo()
        
        if let userId = userData["userId"].number {
            self.userId = userId
            user.userID = userId.stringValue
            UserDefaults.standard.set(userId, forKey: AppConstants.userIDKey)
            UserDefaults.standard.synchronize()
        }
        if let userAlertMode = userData["alertMode"].number {
            self.alertMode = userAlertMode
            user.alertMode.value = userAlertMode.intValue
        }
        if let passwordStatus = userData["isPasswordSet"].number {
            self.isPasswordSet = passwordStatus
            user.hasSetPassword.value = passwordStatus.intValue
        }
        if let sessionKey = userData["sessionKey"].string, sessionKey.count > 1 {
            self.sessionKey = sessionKey
            user.sessionKey = sessionKey
            UserDefaults.standard.set(sessionKey, forKey: AppConstants.sessionKeyForSignedUser)
            UserDefaults.standard.synchronize()
        }
        if let firstName = userData["firstName"].string {
            self.firstName = firstName
            user.firstName = firstName
            UserDefaults.standard.set(firstName, forKey: AppConstants.userFirstNameKey)
        }
        if let lastName = userData["lastName"].string {
            self.lastName = lastName
            user.lastName = lastName
            UserDefaults.standard.set(lastName, forKey: AppConstants.userLastNameKey)
        }
        if let emailId = userData["emailId"].string {
            self.emailId = emailId
            user.emailId = emailId
            UserDefaults.standard.set(emailId, forKey: AppConstants.userEmailKey)
            UserDefaults.standard.synchronize()
        }
        if let phoneNumber = userData["phoneNumber"].string {
            self.phoneNumber = phoneNumber
            user.phoneNumber = phoneNumber
            UserDefaults.standard.set(phoneNumber, forKey: AppConstants.mobileNumberKey)
        }
        if let countryCode = userData["countryCode"].string {
            self.countryCode = countryCode
            user.countryCode = countryCode
            UserDefaults.standard.set(phoneNumber, forKey: AppConstants.countryCodeKey)
        }
        if let imageURL = userData["imageUrl"].string, imageURL.count != 0 {
            self.pictureUrl = imageURL
            user.pictureUrl = imageURL
            UserDefaults.standard.set(imageURL, forKey: AppConstants.pictureURLUser)
            UserDefaults.standard.synchronize()
        }
        if let ringToneName = userData["ringtoneName"].string {
            self.ringToneName = ringToneName
            user.ringToneName = ringToneName
        }
        DispatchQueue.main.async {
            SLRealmManager.sharedInstance.writeUserRecord(userInfo: user)
        }
        UserDefaults.standard.synchronize()
    }
}
