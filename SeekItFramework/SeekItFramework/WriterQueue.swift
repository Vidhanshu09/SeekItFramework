//
//  WriterQueue.swift
//  SeekLib
//
//  Created by Jain, Rahul on 25/01/19.
//  Copyright © 2019 Wavenet Solutions. All rights reserved.
//

import UIKit

public enum OperationType {
    case Buzz
    case StopBuzz
    case BlinkAndBuzz
    case StopBlinkAndBuzz
    case Blink
    case StopBlink
    case Rename
    case SetBuzzTime
    case SetBlinkTime
    case HightAlertMode
    case LowAlertMode
    case PickPocketMode
    case BetterAdaptiveMode
    case PairingCode
    case DeregisterTag
    case TurnOffAlertMode
    case TurnOnAlertMode

}

final public class WriterQueue: NSObject {
    
    public var queue:[Operation] = [Operation]()
    public var isInProcess:Bool = false
    public func addOperation(operation:Operation){
        queue.append(operation)
    }
    
    public func removeAllOperations(){
        queue.removeAll()
    }
    public func invokeQueue()
    {
        isInProcess = true
        guard queue.count > 0 else {
            isInProcess = false
            return
        }        

        if let operation = queue.first{
            queue.removeFirst()

            switch operation.operType{
            case .Buzz:
                    operation.tracker.blinkAndBuzzSensor{ (characterStics) in
                        operation.handler()
                        operation.tracker.serviceModelManager.notifyHandler = nil
                        self.invokeQueue()
                }
            case .StopBuzz:
                operation.tracker.stopBuzzzing{ (characterStics) in
                    operation.handler()
                    operation.tracker.serviceModelManager.notifyHandler = nil
                    self.invokeQueue()

                }
            case .BlinkAndBuzz:
                operation.tracker.blinkAndBuzzSensor { (characterStics) in
                    operation.handler()
                    operation.tracker.serviceModelManager.notifyHandler = nil
                    self.invokeQueue()

                }
            case .StopBlinkAndBuzz:
                operation.tracker.stopBuzzzing{ (characterStics) in
                    operation.handler()
                    operation.tracker.serviceModelManager.notifyHandler = nil
                    self.invokeQueue()

                }
            case .Blink:
                operation.tracker.startBlink{ (characterStics) in
                    operation.handler()
                    operation.tracker.serviceModelManager.notifyHandler = nil
                    self.invokeQueue()

                }
            case .StopBlink:
                operation.tracker.stopBlink{ (characterStics) in
                    operation.handler()
                    operation.tracker.serviceModelManager.notifyHandler = nil
                    self.invokeQueue()

                }
            case .Rename:
                operation.tracker.setDeviceName{(characterStics) in
                    operation.handler()
                    operation.tracker.serviceModelManager.notifyHandler = nil
                    self.invokeQueue()

                }
            case .SetBuzzTime:
                operation.tracker.setBuzzTime{ (characterStics) in
                    operation.handler()
                    operation.tracker.serviceModelManager.notifyHandler = nil
                    self.invokeQueue()

                }
            case .HightAlertMode:
                operation.tracker.setHighAlertMode{ (characterStics) in
                    operation.handler()
                    operation.tracker.serviceModelManager.notifyHandler = nil
                    self.invokeQueue()

                }

            case .LowAlertMode:
                operation.tracker.setLowMode{ (characterStics) in
                    operation.handler()
                    operation.tracker.serviceModelManager.notifyHandler = nil
                    self.invokeQueue()

                }
            case .SetBlinkTime:
                operation.tracker.setLedBlinkTimeDuration{ (characterStics) in
                    operation.handler()
                    operation.tracker.serviceModelManager.notifyHandler = nil
                    self.invokeQueue()

                }

            case .PairingCode:
                operation.tracker.writingPairingCode{ (characterStics) in
                    operation.handler()
                    operation.tracker.serviceModelManager.notifyHandler = nil
                    self.invokeQueue()
                }

            case .PickPocketMode:
                operation.tracker.setPickPocketModeValues{ (characterStics) in
                    operation.handler()
                    operation.tracker.serviceModelManager.notifyHandler = nil
                    self.invokeQueue()
                }
            case .BetterAdaptiveMode:
                operation.tracker.setBetterAdaptiveModeValues{ (characterStics) in
                    operation.handler()
                    operation.tracker.serviceModelManager.notifyHandler = nil
                    self.invokeQueue()

                }
            case .DeregisterTag:
                operation.tracker.deregisterTracker{ (characterStics) in
                    operation.handler()
                    operation.tracker.serviceModelManager.notifyHandler = nil
                    self.invokeQueue()
                }

            case .TurnOffAlertMode:
                operation.tracker.turnOffAlertMode{ (characterStics) in
                    operation.handler()
                    operation.tracker.serviceModelManager.notifyHandler = nil
                    self.invokeQueue()
                }
            case .TurnOnAlertMode:
                operation.tracker.turnOnAlertMode{ (characterStics) in
                    operation.handler()
                    operation.tracker.serviceModelManager.notifyHandler = nil
                    self.invokeQueue()
                }
            }
        }

    }
}

public class Operation{
    public var tracker:TrackerDevice
    public var handler:()->()
    public var operType:OperationType
    
    public init(bleTracker:TrackerDevice,type:OperationType ,complitionHandler:@escaping ()->()) {
        tracker = bleTracker
        handler = complitionHandler
        operType = type
    }
}
