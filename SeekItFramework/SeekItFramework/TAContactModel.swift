//
//  TAContactModel.swift
//  SeekLib
//
//  Created by Jitendra Chamoli on 09/10/18.
//

import Foundation
import SwiftyJSON

public class TAContactList: NSObject {
    
    public var contactsArray:[TAContact]?
    
    override init() {
    }
    
    required public init (listArray: JSON) {
        
        self.contactsArray = [TAContact]()
        
        if listArray.count > 0 {
            for item in listArray.array! {
                let contact = TAContact(contactDict: item)
                self.contactsArray?.append(contact)
            }
        }
    }
}

public class TAContact: NSObject {
    
    public var contactName: String?
    public var contactPhone: String?
    
    override init() {
    }
    
    required public init (contactDict: JSON) {
        
        if let phoneNumber = contactDict["contactNumber"].string {
            self.contactPhone = phoneNumber
        }
        if let name = contactDict["contactName"].string {
            self.contactName = name
        }
    }
}
