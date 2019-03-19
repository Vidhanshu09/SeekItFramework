//
//  SSIDUtility.swift
//  SeekLib
//
//  Created by Jitendra Chamoli on 09/10/18.
//

import Foundation
import SystemConfiguration.CaptiveNetwork

public class SSID {
    
    public class func fetchSSIDInfo() -> [String: Any] {
        var interface = [String: Any]()
        if let interfaces = CNCopySupportedInterfaces() {
            for i in 0..<CFArrayGetCount(interfaces){
                let interfaceName = CFArrayGetValueAtIndex(interfaces, i)
                let rec = unsafeBitCast(interfaceName, to: AnyObject.self)
                guard let unsafeInterfaceData = CNCopyCurrentNetworkInfo("\(rec)" as CFString) else {
                    return interface
                }
                guard let interfaceData = unsafeInterfaceData as? [String: Any] else {
                    return interface
                }
                interface = interfaceData
            }
        }
        return interface
    }
}
