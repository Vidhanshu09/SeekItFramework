//
//  RealmManager.swift
//  SeekLib
//
//  Created by Jitendra Chamoli on 09/10/18.
//

import Foundation
import RealmSwift
import CocoaLumberjack

public class SLRealmManager: NSObject {
    
    // MARK: - Instantiate Realm Instance
    lazy public var realm: Realm = {
        
        /*let config = Realm.Configuration(
         // Set the new schema version. This must be greater than the previously used
         // version (if you've never set a schema version before, the version is 0).
         schemaVersion: 2,
         
         // Set the block which will be called automatically when opening a Realm with
         // a schema version lower than the one set above
         migrationBlock: { migration, oldSchemaVersion in
         // We haven’t migrated anything yet, so oldSchemaVersion == 0
         if (oldSchemaVersion < 1) {
         // Nothing to do!
         // Realm will automatically detect new properties and removed properties
         // And will update the schema on disk automatically
         }
         })
         
         // Tell Realm to use this new configuration object for the default Realm
         Realm.Configuration.defaultConfiguration = config
         
         // Now that we've told Realm how to handle the schema change, opening the file
         // will automatically perform the migration
         */
        return try! Realm()
    }()
    
    /**
     Shared instance for RealmManager
     */
    public static var sharedInstance = SLRealmManager()
    
    fileprivate override init() {
        super.init()
        DDLogVerbose("*** RealmManager instance Started ***")
    }
    
    deinit {
        DDLogVerbose("RealmManager deallocated")
    }
    
    func setupRealm(){
        // Setup Configuration for Realm
    }
    
    //==========================================================================
    // MARK:- Read Notify history stored in Realm DB
    //==========================================================================
    
    public func readNotifyRecord(notifyId:String) -> NotifyHistoryInfo?{
        
        do {
            let realm = try Realm()
            if let notify = realm.object(ofType: NotifyHistoryInfo.self, forPrimaryKey: notifyId) {
                return notify
            }
        } catch let error as NSError {
            // handle error
            DDLogVerbose("Error While reading notify records: \(error.localizedDescription)")
        }
        return nil
    }
    
    //==========================================================================
    // MARK:- Writes New Notify Record into Realm DB
    //==========================================================================
    
    public func writeNotifyRecord(notify:NotifyHistoryInfo){
        do {
            let realm = try Realm()
            try realm.write() {
                realm.add(notify, update: true)
            }
        } catch let error as NSError {
            DDLogVerbose("Error While writing notify records: \(error.localizedDescription)")
        }
    }
    
    //==========================================================================
    // MARK:- Delete Any Specific Notify Record from Realm DB
    //==========================================================================
    
    public func deleteNotifyRecord(notify:NotifyHistoryInfo){
        do {
            let realm = try Realm()
            try realm.write() {
                realm.delete(notify)
            }
        } catch let error as NSError {
            DDLogVerbose("Error While deleting notify records: \(error.localizedDescription)")
        }
    }
    
    //==========================================================================
    // MARK:- Read All Notify Records from Realm DB
    //==========================================================================
    
    public func readAllNotifyRecords() -> [NotifyHistoryInfo]{
        do {
            let realm = try Realm()
            return Array(realm.objects(NotifyHistoryInfo.self))
        } catch let error as NSError {
            // handle error
            DDLogVerbose("Error While reading notifications: \(error.localizedDescription)")
        }
        return [NotifyHistoryInfo]()
    }
    
    //==========================================================================
    // MARK:- Delete All Notification History from Realm DB
    //==========================================================================
    
    public func deleteAllNotifyHistory(){
        
        var notifyRecords = self.readAllNotifyRecords()
        do {
            let realm = try Realm()
            try realm.write() {
                for obj in notifyRecords {
                    realm.delete(obj)
                }
            }
        } catch let error as NSError {
            DDLogVerbose("Error While deleting all notify records: \(error.localizedDescription)")
        }
        notifyRecords = self.readAllNotifyRecords()
        DDLogVerbose("Delete All Notifications - NumberOfRecords in realm: \(notifyRecords.count)")
    }
    
    //==========================================================================
    // MARK:- Read all Device record in Realm DB
    //==========================================================================
    
    public func readDeviceRecords() -> [TrackersInfo]{
        do {
            let realm = try Realm()
            return Array(realm.objects(TrackersInfo.self))
        } catch let error as NSError {
            DDLogVerbose("Error While reading device records: \(error.localizedDescription)")
        }
        return [TrackersInfo]()
    }
    
    //==========================================================================
    // MARK:- Read Notify history stored in Realm DB
    //==========================================================================
    
    public func readDeviceRecord(deviceId:String) -> TrackersInfo?{
        do {
            let realm = try Realm()
            if let deviceRecord = realm.object(ofType: TrackersInfo.self, forPrimaryKey: deviceId) {
                return deviceRecord
            }
        } catch let error as NSError {
            DDLogVerbose("Error While reading device record: \(error.localizedDescription)")
        }
        return nil
    }
    
    //==========================================================================
    // MARK:- Writes New BLE device Info into Realm DB
    //==========================================================================
    
    public func writeDeviceRecord(device:TrackersInfo){
        do {
            let realm = try Realm()
            try realm.write() {
                realm.add(device, update: true)
            }
        } catch let error as NSError {
            DDLogVerbose("Error While writing new device record: \(error.localizedDescription)")
        }
    }
    
    //==========================================================================
    // MARK:- Delete single BLE device Info from Realm DB
    //==========================================================================
    
    public func deleteDeviceRecord(device:TrackersInfo){
        do {
            let realm = try Realm()
            try realm.write() {
                realm.delete(device)
            }
        } catch let error as NSError {
            DDLogVerbose("Error While deleting device record: \(error.localizedDescription)")
        }
    }
    
    //==========================================================================
    // MARK:- Delete All BLE device Info from Realm DB
    //==========================================================================
    
    public func deleteAllDeviceRecord() {
        var deviceRecords = self.readDeviceRecords()
        do {
            let realm = try Realm()
            try realm.write() {
                for obj in deviceRecords {
                    realm.delete(obj)
                }
            }
        } catch let error as NSError {
            DDLogVerbose("Error While deleting all device records: \(error.localizedDescription)")
        }
        deviceRecords = self.readDeviceRecords()
        DDLogVerbose("Delete All Action - NumberRecords in realm: \(deviceRecords.count)")
    }
    
    // User
    
    //==========================================================================
    // MARK:- Writes User Information on DB
    //==========================================================================
    
    public func writeUserRecord(userInfo:UserProfileInfo) {
        do {
            let realm = try Realm()
            try realm.write() {
                realm.add(userInfo, update: true)
            }
        } catch let error as NSError {
            DDLogVerbose("Error While writing new user record: \(error.localizedDescription)")
        }
    }
    
    //==========================================================================
    // MARK:- Read Specific User's Information on DB
    //==========================================================================
    
    public func readUserRecord(userId:String) -> UserProfileInfo? {
        do {
            let realm = try Realm()
            if let userRecord = realm.object(ofType: UserProfileInfo.self, forPrimaryKey: userId) {
                return userRecord
            }
        } catch let error as NSError {
            DDLogVerbose("Error While reading user record: \(error.localizedDescription)")
        }
        return nil
    }
    
    //==========================================================================
    // MARK:- Read All User's Records from Realm DB
    //==========================================================================
    
    public func readAllUsersRecords() -> [UserProfileInfo] {
        
        do {
            let realm = try Realm()
            return Array(realm.objects(UserProfileInfo.self))
        } catch let error as NSError {
            DDLogVerbose("Error While reading all user records: \(error.localizedDescription)")
        }
        return [UserProfileInfo]()
    }
    
    //==========================================================================
    // MARK:- Delete User's record from DB
    //==========================================================================
    
    public func deleteUserRecord(userInfo:UserProfileInfo) {
        do {
            let realm = try Realm()
            try realm.write() {
                realm.delete(userInfo)
            }
        } catch let error as NSError {
            DDLogVerbose("Error While deleting user record: \(error.localizedDescription)")
        }
    }
    
    //==========================================================================
    // MARK:- Delete All User's Record from Current Phone
    //==========================================================================
    
    public func deleteAllUsersRecord() {
        
        let userRecords = self.readAllUsersRecords()
        do {
            let realm = try Realm()
            try realm.write() {
                for obj in userRecords {
                    realm.delete(obj)
                }
            }
        } catch let error as NSError {
            DDLogVerbose("Error While deleting all user records: \(error.localizedDescription)")
        }
        DDLogVerbose("After Deletting All User's Action - Number of User's Record count in realm: \(readAllUsersRecords().count)")
    }
    
    //==========================================================================
    // MARK:- WiFi Records
    //==========================================================================
    
    public func writeWifiRecord(wifi:WifiInfo) {
        do {
            let realm = try Realm()
            try realm.write() {
                realm.add(wifi, update: true)
            }
        } catch let error as NSError {
            DDLogVerbose("Error While writing new wifi record: \(error.localizedDescription)")
        }
    }
    
    public func readWiFiRecords() -> [WifiInfo] {
        do {
            let realm = try Realm()
            return Array(realm.objects(WifiInfo.self))
        } catch let error as NSError {
            DDLogVerbose("Error While reading all wifi records: \(error.localizedDescription)")
        }
        return [WifiInfo]()
    }
    
    public func deleteAllWiFiHistory() {
        
        var wifiRecords = self.readWiFiRecords()
        do {
            let realm = try Realm()
            try realm.write() {
                for obj in wifiRecords {
                    realm.delete(obj)
                }
            }
        } catch let error as NSError {
            DDLogVerbose("Error While deleting all wifi record: \(error.localizedDescription)")
        }
        wifiRecords = self.readWiFiRecords()
        DDLogVerbose("After Delete All Wifi Records - NumberOfRecords in realm: \(wifiRecords.count)")
    }
    
    public func deleteWifiRecord(wifi:WifiInfo) {
        do {
            let realm = try Realm()
            try realm.write() {
                realm.delete(wifi)
            }
        } catch let error as NSError {
            DDLogVerbose("Error While deleting a wifi record: \(error.localizedDescription)")
        }
    }
    
    //==========================================================================
    // MARK:- Sleep Records
    //==========================================================================
    
    public func writeSleepRecord(sleepInfo:SleepInfo) {
        do {
            let realm = try Realm()
            try realm.write() {
                realm.add(sleepInfo, update: true)
            }
        } catch let error as NSError {
            DDLogVerbose("Error While adding sleep record: \(error.localizedDescription)")
        }
    }
    
    public func readSleepRecord(userID:String) -> SleepInfo? {
        do {
            let realm = try Realm()
            if let sleepRecord = realm.object(ofType: SleepInfo.self, forPrimaryKey: userID) {
                return sleepRecord
            }
        } catch let error as NSError {
            DDLogVerbose("Error While reading a sleep record: \(error.localizedDescription)")
        }
        return nil
    }
    
    public func readAllSleepRecords() -> [SleepInfo] {
        do {
            let realm = try Realm()
            return Array(realm.objects(SleepInfo.self))
        } catch let error as NSError {
            DDLogVerbose("Error While reading all sleep records: \(error.localizedDescription)")
        }
        return [SleepInfo]()
    }
    
    public func deleteAllSleepRecords() {
        
        let sleepRecords = self.readAllSleepRecords()
        do {
            let realm = try Realm()
            try realm.write() {
                for obj in sleepRecords {
                    realm.delete(obj)
                }
            }
        } catch let error as NSError {
            DDLogVerbose("Error While deleting all sleep record: \(error.localizedDescription)")
        }
        DDLogVerbose("After Deletting All Sleep Records Action - Number of Sleep Record count in realm: \(readAllSleepRecords().count)")
    }
    
    //==========================================================================
    // MARK:- Audio Records
    //==========================================================================
    
    public func writeAudioCache(audioInfo:AudioCache) {
        do {
            let realm = try Realm()
            try realm.write() {
                realm.add(audioInfo, update: true)
            }
        } catch let error as NSError {
            DDLogVerbose("Error While adding new audio record: \(error.localizedDescription)")
        }
    }
    
    public func readAllAudioCache() -> [AudioCache] {
        do {
            let realm = try Realm()
            return Array(realm.objects(AudioCache.self))
        } catch let error as NSError {
            DDLogVerbose("Error While reading all audio records: \(error.localizedDescription)")
        }
        return [AudioCache]()
    }
    
    public func deleteAllAudioCache() {
        let audioRecords = self.readAllAudioCache()
        do {
            let realm = try Realm()
            try realm.write {
                for obj in audioRecords {
                    realm.delete(obj)
                }
            }
        } catch let error as NSError {
            DDLogVerbose("Error While reading all audio records: \(error.localizedDescription)")
        }
        DDLogVerbose("After Deletting All Audio Cache Records Action - Number of Audio Cache Record count in realm: \(readAllAudioCache().count)")
    }
    
    
    //==========================================================================
    // MARK:- Read Lost Locatoin history stored in Realm DB
    //==========================================================================
    
    public func readLostLocationRecords(sensorUUID:String) -> [LostTrackerLocation]{
        do {
            let realm = try Realm()
            let lostRecords = realm.objects(LostTrackerLocation.self)
            return Array(lostRecords)
            
        } catch let error as NSError {
            // handle error
            DDLogVerbose("Error While reading notify records: \(error.localizedDescription)")
        }
        return []
    }
    
    //==========================================================================
    // MARK:- Writes New Lost Location Record into Realm DB
    //==========================================================================
    
    public func writeLostLocationRecord(location:LostTrackerLocation) {
        do {
            let realm = try Realm()
            try realm.write() {
                realm.add(location, update: false)
            }
        } catch let error as NSError {
            DDLogVerbose("Error While writing notify records: \(error.localizedDescription)")
        }
    }
    
    //==========================================================================
    // MARK:- Read last knowm Locatoin sensor stored in Realm DB
    //==========================================================================
    
    public func readTrackerLastKnownLocation(sensorUUID:String) -> [TrackerLastKnownLocation]{
        do {
            let realm = try Realm()
            let lostRecords = realm.objects(TrackerLastKnownLocation.self).filter("sensorUUID = %@", sensorUUID)
            return Array(lostRecords)
            
        } catch let error as NSError {
            // handle error
            DDLogVerbose("Error While reading notify records: \(error.localizedDescription)")
        }
        return []
    }
    
    //==========================================================================
    // MARK:- Writes or Updates New last Known Location Record into Realm DB
    //==========================================================================
    
    public func writeTrackerLastKnownLocation(location:TrackerLastKnownLocation) {
        do {
            let realm = try Realm()
            let lostRecords = realm.objects(TrackerLastKnownLocation.self).filter("sensorUUID = %@", location.sensorUUID)
            if let record = lostRecords.first {
                try realm.write() {
                    record.latitude = location.latitude
                    record.longitude = location.longitude
                    record.time = location.time
                }
            } else {
                try realm.write() {
                    realm.add(location, update: false)
                }
            }
        } catch let error as NSError {
            DDLogVerbose("Error While writing notify records: \(error.localizedDescription)")
        }
    }
    
    
    //==========================================================================
    // MARK:- Internal Logs Records
    //==========================================================================
    
    public func writeLog(logInfo:TrackerLog) {
        do {
            let realm = try Realm()
            try realm.write {
                realm.add(logInfo, update: true)
            }
        } catch let error as NSError {
            DDLogVerbose("Error While writing new log record: \(error.localizedDescription)")
        }
    }
    
    public func readAllLogs() -> [TrackerLog] {
        do {
            let realm = try Realm()
            return Array(realm.objects(TrackerLog.self))
        } catch let error as NSError {
            DDLogVerbose("Error While reading all log records: \(error.localizedDescription)")
        }
        return [TrackerLog]()
    }
    
    public func readAllLogsForTracker(trackerUUID: String) -> [TrackerLog] {
        do {
            let realm = try Realm()
            return Array(realm.objects(TrackerLog.self).filter("trackerUUID == '\(trackerUUID)'"))
        } catch let error as NSError {
            DDLogVerbose("Error While reading all log records: \(error.localizedDescription)")
        }
        return [TrackerLog]()
    }
    
    public func deleteAllLogs() {
        let logRecords = self.readAllLogs()
        do {
            let realm = try Realm()
            try realm.write {
                for obj in logRecords {
                    realm.delete(obj)
                }
            }
        } catch let error as NSError {
            DDLogVerbose("Error While deleting all log records: \(error.localizedDescription)")
        }
        DDLogVerbose("After Deleting All internal logs Records Action - Number of Internal Logs Record count in realm: \(readAllLogs().count)")
    }
    
    //==========================================================================
    // MARK:- Phone number for Social login
    //==========================================================================
    //
    //    func writeContact(contactIndo:ContactInfo) {
    //        do {
    //            let realm = try Realm()
    //            try realm.write {
    //                realm.add(contactIndo, update: true)
    //            }
    //        } catch let error as NSError {
    //            DDLogVerbose("Error While writing new log record: \(error.localizedDescription)")
    //        }
    //    }
    
    //    func readAllContact() -> [ContactInfo] {
    //        do {
    //            let realm = try Realm()
    //            return Array(realm.objects(ContactInfo.self))
    //        } catch let error as NSError {
    //            DDLogVerbose("Error While reading all log records: \(error.localizedDescription)")
    //        }
    //        return [ContactInfo]()
    //    }
    
}

