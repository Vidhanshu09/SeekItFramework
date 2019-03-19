//
//  SensorManagerDelegate.swift
//  SeekLib
//
//  Created by Jitendra Chamoli on 09/10/18.
//

import Foundation

public protocol SLSensorManagerDelegate: class {
    
    /**
     Called when the `Manager` did find a peripheral and did add it to the foundDevices array.
     */
    //func manager(_ manager: SensorManager, didFindDevice device: Device)
    
    /**
     Called when the `Manager` is trying to connect to device
     */
    //func manager(_ manager: SensorManager, willConnectToDevice device: Device)
    
    /**
     Called when the `Manager` did connect to the device.
     */
    //func manager(_ manager: SensorManager, connectedToDevice device: Device)
    
    /**
     Called when the `Manager` did disconnect from the device.
     Retry will indicate if the Manager will retry to connect when it becomes available.
     */
    //func manager(_ manager: SensorManager, disconnectedFromDevice device: Device, willRetry retry: Bool)
    
    /**
     Called whenever Bluetooth power state is changed. | ON/OFF
     */
    func manager(_ manager: SLSensorManager, powerState:Bool)
}
