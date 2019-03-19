//
//  TAWifiModel.swift
//  SeekLib
//
//  Created by Jitendra Chamoli on 09/10/18.
//

import Foundation
import SwiftyJSON

public class TAWifiList: NSObject {
    
    public var wifiArray:[TAWifi]?
    
    override init() {
    }
    
    required public init (listArray: JSON) {
        
        self.wifiArray = [TAWifi]()
        
        if listArray.count > 0 {
            for item in listArray.array! {
                let wifi = TAWifi(wifiDict: item)
                let newWifi:WifiInfo = WifiInfo()
                
                if let ssid = wifi.wifiSSIDString {
                    newWifi.wifiSSID = ssid
                }
                if let bssid = wifi.wifiBSSIDString {
                    newWifi.wifiBSSID = bssid
                }
                if let location = wifi.wifiLocation {
                    newWifi.wifiLocation = location
                }
                
                DispatchQueue.main.async {
                    SLRealmManager.sharedInstance.writeWifiRecord(wifi: newWifi)
                }
                self.wifiArray?.append(wifi)
            }
        }
    }
}

public class TAWifi: NSObject {
    
    public var wifiLocation: String?
    public var wifiSSIDString: String?
    public var wifiBSSIDString: String?
    
    override init() {
    }
    
    required public init (wifiDict: JSON) {
        
        if let location = wifiDict["location"].string {
            self.wifiLocation = location
        }
        if let ssid = wifiDict["ssid"].string {
            self.wifiSSIDString = ssid
        }
        if let bssid = wifiDict["bssid"].string {
            self.wifiBSSIDString = bssid
        }
    }
}

