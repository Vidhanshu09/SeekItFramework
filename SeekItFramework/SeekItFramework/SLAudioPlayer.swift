//
//  TAAudioPlayer.swift
//  SeekLib
//
//  Created by Jitendra Chamoli on 09/10/18.
//

import Foundation
import AVFoundation
import MediaPlayer
import UIKit
import AudioToolbox
import CocoaLumberjack
import CallKit

public class SLAudioPlayer: NSObject {
    
    private var audioPlayer: AVAudioPlayer?
    var checkVolumeTimer: Timer?
    var callObserver: CXCallObserver!
    private var systemVol:Float?
    var tempURL:URL?
    // Returns TRUE/YES if the user is currently on a phone call
    var isOnPhoneCall:Bool = false
    
    /**
     Shared instance for TAAudioPlayer
     */
    public static let sharedInstance = SLAudioPlayer()
    
    private override init() {
        super.init()
        setupCallObserver()
    }
    
    private func setupCallObserver(){
        callObserver = CXCallObserver()
        callObserver.setDelegate(self, queue: nil)
    }
    
    private func initSound(soundUrl: String, soundName: String) {
        
        //NotificationCenter.default.addObserver(self, selector: #selector(TAAudioPlayer.audioSessionInterrupted(_:)), name: NSNotification.Name.AVAudioSessionInterruption, object: AVAudioSession.sharedInstance())
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playAndRecord, mode: .default, options: .mixWithOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            try audioSession.overrideOutputAudioPort(AVAudioSession.PortOverride.speaker)
            
            // Config Volume System
            UIApplication.shared.beginReceivingRemoteControlEvents()
            //let volumeView = MPVolumeView()
            systemVol = MPVolumeView().volumeSlider.value
            print("System Volume: \(MPVolumeView().volumeSlider.value)")
            setMediaVolume(volume: 1.0)
            //volumeView.volumeSlider.setValue(1.0, animated: false)
            
            // Check Volume level
            checkVolumeTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(incrementVolume(_:)), userInfo: nil, repeats: true)
            
        } catch let error as NSError {
            DDLogVerbose("an error occurred while intialiazing audio session category.\n \(error.localizedDescription)")
        }
        // Default RingTone
        var url = URL(fileURLWithPath: Bundle.main.path(forResource: "opening", ofType: ".mp3")!)
        if soundUrl.count > 1 {
            
            /*//let sUrl = URL(string: soundUrl)!
             
             let sUrl = URL(string: "https://13.59.36.23:5000/ringtones/GWbwjeFlgW_2221.mp3")!
             let playerItem = CachingPlayerItem(url: sUrl)
             playerItem.download()
             playerItem.delegate = self
             //player = AVPlayer(playerItem: playerItem)
             if #available(iOS 10.0, *) {
             //player.automaticallyWaitsToMinimizeStalling = false
             } else {
             // Fallback on earlier versions
             }
             //player.play()*/
            if let audioDetail = SLRealmManager.sharedInstance.readAllAudioCache().filter({ $0.serverURL == soundUrl }).first {
                let fileMngr = FileManager.default
                // Full path to documents directory
                let dirPaths = fileMngr.urls(for: .documentDirectory, in: .userDomainMask)
                let docsDir = dirPaths[0]
                DDLogVerbose(" Trying to play using  \(soundUrl)")
                DDLogVerbose(" Trying to play using local url  \(audioDetail.localPath)")
                let localAudioURL = docsDir.appendingPathComponent(audioDetail.localPath)
                do {
                    try audioPlayer = AVAudioPlayer(contentsOf: localAudioURL)
                    audioPlayer?.delegate = self
                    audioPlayer?.prepareToPlay()
                    if #available(iOS 10.0, *) {
                        audioPlayer?.setVolume(1.0, fadeDuration: 0.5)
                    } else {
                        audioPlayer?.volume = 1.0
                    }
                    audioPlayer?.numberOfLoops = -1
                    audioPlayer?.play()
                } catch let err {
                    DDLogVerbose(" !!!!!!!!!! Could not intialize AudioPlayer !!!!!!!!!!!! \(err.localizedDescription)")
                    return
                }
            } else {
                // Download Audio and then Play
                AudioManager.shared.retrieveAudio(for: soundUrl)
            }
        } else {
            // RingTone Downloaded from Server
            //if let selectedRingTone = CloudConnector.sharedInstance.userProfile?.ringToneName,
            if let downloadedRings = SLCloudConnector.sharedInstance.listFilesFromDocumentsFolder(), downloadedRings.count > 0 {
                let fileMngr = FileManager.default
                // Full path to documents directory
                let dirPaths = fileMngr.urls(for: .documentDirectory, in: .userDomainMask)
                let docsDir = dirPaths[0]
                let filePath =  docsDir.appendingPathComponent("ringtones")
                
                //                if soundName == "Default"{
                //                    url = URL(fileURLWithPath: Bundle.main.path(forResource: "opening", ofType: ".mp3")!)
                //                }else{
                //                    url = filePath.appendingPathComponent("\(soundName).mp3")
                //                }
                
                switch soundName {
                case "Default":
                    url = URL(fileURLWithPath: Bundle.main.path(forResource: "opening", ofType: ".mp3")!)
                    break
                    //                case "Alarm 1":
                    //                    url = filePath.appendingPathComponent("Alarm 1.mp3")
                    //                    break
                    //                case "Alarm 2":
                    //                    url = filePath.appendingPathComponent("Alarm 2.mp3")
                    //                    break
                    //                case "Alarm 3":
                    //                    url = filePath.appendingPathComponent("Alarm 3.mp3")
                    //                    break
                    //                case "Alarm 4":
                    //                    url = filePath.appendingPathComponent("Alarm 4.mp3")
                    //                    break
                    //                case "Alarm 5":
                    //                    url = filePath.appendingPathComponent("Alarm 5.mp3")
                //                    break
                default:
                    url = filePath.appendingPathComponent("\(soundName).mp3")
                    if !fileMngr.fileExists(atPath: url.path){
                        url = URL(fileURLWithPath: Bundle.main.path(forResource: "opening", ofType: ".mp3")!)
                    }
                    break
                }
                //url = tempURL! //docsDir.appendingPathComponent("TRHsMAFMkC_2221.mp3")
                //print(url)
                do {
                    try audioPlayer = AVAudioPlayer(contentsOf: url)
                    audioPlayer?.delegate = self
                    audioPlayer?.prepareToPlay()
                    if #available(iOS 10.0, *) {
                        audioPlayer?.setVolume(1.0, fadeDuration: 0.5)
                    } else {
                        audioPlayer?.volume = 1.0
                    }
                    audioPlayer?.numberOfLoops = -1
                    audioPlayer?.play()
                } catch let err {
                    DDLogVerbose(" !!!!!!!!!! Could not intialize AudioPlayer !!!!!!!!!!!! \(err.localizedDescription)")
                    return
                }
            } else {
                url = URL(fileURLWithPath: Bundle.main.path(forResource: "opening", ofType: ".mp3")!)
                do {
                    try audioPlayer = AVAudioPlayer(contentsOf: url)
                    audioPlayer?.delegate = self
                    audioPlayer?.prepareToPlay()
                    if #available(iOS 10.0, *) {
                        audioPlayer?.setVolume(1.0, fadeDuration: 0.5)
                    } else {
                        audioPlayer?.volume = 1.0
                    }
                    audioPlayer?.numberOfLoops = -1
                    audioPlayer?.play()
                } catch let err {
                    DDLogVerbose(" !!!!!!!!!! Could not intialize AudioPlayer !!!!!!!!!!!! \(err.localizedDescription)")
                    return
                }
            }
        }
        systemVol = MPVolumeView().volumeSlider.value
        print("System Volume: \(MPVolumeView().volumeSlider.value)")
        setMediaVolume(volume: 1.0)
    }
    
    public func stopSound() {
        checkVolumeTimer?.invalidate()
        if let audioPlayer = audioPlayer {
            if audioPlayer.isPlaying {
                audioPlayer.pause() // stop()
                if let previousSystemVol = systemVol {
                    self.setMediaVolume(volume: previousSystemVol)
                }
            }
        }
        //player.pause()
    }
    
    func playSoundOnce() {
        audioPlayer?.play()
        //AudioServicesPlaySystemSound(1352)
        //AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
    }
    
    public func playLoopingSound(alertMode: NSNumber, buzzType:String, ringURL: String, ringName: String) {
        switch buzzType {
        case "normal":
            startRingingMobile(ringURL: ringURL, ringName: ringName)
            break
        case "disconnected":
            // ** TO CHECK SLEEP MODE AND WIFI MODE SETTINGS ** //
            let sleepModeActive = SLSensorManager.sharedInstance.isSleepModeActivated()
            let wifiModeActive = SLSensorManager.sharedInstance.isWifiModeActivated()
            
            if alertMode == AppConstants.HIGH_ALERT_MODE && buzzType != "disconnected"
                && !(sleepModeActive || wifiModeActive) {
                startRingingMobile(ringURL: ringURL, ringName: ringName)
            }
            break
        default:
            break
        }
    }
    
    @objc func vibratePattern() {
        
        if let audioPlayer = self.audioPlayer {
            if audioPlayer.isPlaying {
                AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
            }
        }
    }
    
    // Check Volume Level
    @objc func incrementVolume(_ timer:Timer) {
        
        let volumeView = MPVolumeView()
        if volumeView.volumeSlider.value < 1.0 {
            //volumeView.volumeSlider.setValue(1.0, animated: false)
            //setMediaVolume(volume: 1.0)
        }
    }
    
    func startRingingMobile(ringURL: String, ringName: String) {
        if !isOnPhoneCall {
            initSound(soundUrl: ringURL, soundName: ringName)
            Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(vibratePattern), userInfo: nil, repeats: true)
        } else {
            for _ in 0..<7 {
                AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
            }
        }
    }
    
    // MARK: - Notifications
    
    @objc class func audioSessionInterrupted(_ notification:Notification) {
        DDLogVerbose("interruption received: \(notification)")
    }
    
    func setMediaVolume(volume : Float) {
        print("Setting System Volume: \(volume)")
        DispatchQueue.main.async {
            MPVolumeView.setVolume(volume)
        }
    }
}

// MARK:- MPVolumeView Extension | System Volume

extension MPVolumeView {
    
    var volumeSlider:UISlider {
        self.showsRouteButton = false
        self.showsVolumeSlider = false
        self.isHidden = true
        var slider = UISlider()
        for subview in self.subviews {
            if subview.isKind(of: UISlider.self) {
                slider = subview as! UISlider
                slider.isContinuous = false
                (subview as! UISlider).value = AVAudioSession.sharedInstance().outputVolume
                return slider
            }
        }
        return slider
    }
}

extension MPVolumeView {
    static func setVolume(_ volume: Float) {
        let volumeView = MPVolumeView()
        let slider = volumeView.subviews.first(where: { $0 is UISlider }) as! UISlider
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.02) {
            slider.value = volume;
            print("Updated System Volume: \(MPVolumeView().volumeSlider.value)")
        }
    }
}

// MARK: AVAudioPlayerDelegate

extension SLAudioPlayer: AVAudioPlayerDelegate {
    
    // Did Finish Playing
    private func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Send stop action
        // stopAction()
    }
    
    // Player Decode Error Did Occur
    private func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DDLogVerbose("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
        DDLogVerbose("audioPlayerDecodeErrorDidOccur: \(String(describing: error?.localizedDescription))")
        DDLogVerbose("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
    }
}

extension SLAudioPlayer: CXCallObserverDelegate {
    
    public func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        
        if call.hasEnded == true {
            isOnPhoneCall = false
            //            SensorManager.sharedInstance.startScan()
            //            SensorManager.sharedInstance.startAutoConnectTimer()
            print("CXCallState :Disconnected")
        }
        if call.isOutgoing == true && call.hasConnected == false {
            isOnPhoneCall = true
            print("CXCallState :Dialing")
        }
        if call.isOutgoing == false && call.hasConnected == false && call.hasEnded == false {
            isOnPhoneCall = true
            print("CXCallState :Incoming")
        }
        
        if call.hasConnected == true && call.hasEnded == false {
            isOnPhoneCall = true
            //            SensorManager.sharedInstance.stopScan()
            //            SensorManager.sharedInstance.stopAutoConnectTimer()
            print("CXCallState : Connected")
        }
    }
}
