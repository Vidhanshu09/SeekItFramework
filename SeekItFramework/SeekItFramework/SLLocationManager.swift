//
//  TALocationManager.swift
//  SeekLib
//
//  Created by Jitendra Chamoli on 09/10/18.
//

import Foundation
import CoreLocation
import CoreMotion
import MapKit
import CocoaLumberjack


public typealias LMReverseGeocodeCompletionHandler = ((_ reverseGecodeInfo:NSDictionary?,_ placemark:CLPlacemark?, _ error:String?)->Void)?
public typealias LMGeocodeCompletionHandler = ((_ gecodeInfo:NSDictionary?,_ placemark:CLPlacemark?, _ error:String?)->Void)?
public typealias LMLocationCompletionHandler = ((_ latitude:Double, _ longitude:Double, _ status:String, _ verboseMessage:String, _ error:String?)->())?

// Todo: Keep completion handler differerent for all services, otherwise only one will work
public enum GeoCodingType {
    
    case geocoding
    case reverseGeocoding
}

public class SLLocationManager: NSObject, CLLocationManagerDelegate {
    
    /* Private variables */
    fileprivate var completionHandler:LMLocationCompletionHandler
    
    fileprivate var reverseGeocodingCompletionHandler:LMReverseGeocodeCompletionHandler
    fileprivate var geocodingCompletionHandler:LMGeocodeCompletionHandler
    
    fileprivate var locationStatus : NSString = "Calibrating"// to pass in handler
    public var locationManager: CLLocationManager = CLLocationManager()
    
    private let motionManager = CMMotionActivityManager()
    fileprivate var verboseMessage = "Calibrating"
    public var userLocationCordinate:CLLocationCoordinate2D?
    
    fileprivate let verboseMessageDictionary = [CLAuthorizationStatus.notDetermined:"You have not yet made a choice with regards to this application.",
                                                CLAuthorizationStatus.restricted:"This application is not authorized to use location services. Due to active restrictions on location services, the user cannot change this status, and may not have personally denied authorization.",
                                                CLAuthorizationStatus.denied:"You have explicitly denied authorization for this application, or location services are disabled in Settings.",
                                                CLAuthorizationStatus.authorizedAlways:"App is Authorized to use location services.",
                                                CLAuthorizationStatus.authorizedWhenInUse:"You have granted authorization to use your location only when the app is visible to you."]
    
    public var delegate:SLLocationManagerDelegate? = nil
    
    public var latitude:Double = 0.0
    public var longitude:Double = 0.0
    
    public var latitudeAsString:String = ""
    public var longitudeAsString:String = ""
    
    
    public var lastKnownLatitude:Double = 0.0
    public var lastKnownLongitude:Double = 0.0
    
    public var lastKnownLatitudeAsString:String = ""
    public var lastKnownLongitudeAsString:String = ""
    
    
    var keepLastKnownLocation:Bool = true
    var hasLastKnownLocation:Bool = true
    
    public var autoUpdate:Bool = true
    
    var showVerboseMessage = false
    
    public var isRunning = false
    
    public static let sharedInstance = SLLocationManager()
    //private init() {}
    
    
    /*class var sharedInstance : TALocationManager {
     struct Static {
     static let instance : TALocationManager = TALocationManager()
     }
     return Static.instance
     }*/
    
    
    private override init() {
        super.init()
        initLocationManager()
        if(!autoUpdate){
            // Set the delegate
            locationManager.delegate = self
            autoUpdate = !CLLocationManager.significantLocationChangeMonitoringAvailable()
        }
    }
    
    fileprivate func resetLatLon(){
        
        latitude = 0.0
        longitude = 0.0
        
        latitudeAsString = ""
        longitudeAsString = ""
        
    }
    
    fileprivate func resetLastKnownLatLon(){
        
        hasLastKnownLocation = false
        
        lastKnownLatitude = 0.0
        lastKnownLongitude = 0.0
        
        lastKnownLatitudeAsString = ""
        lastKnownLongitudeAsString = ""
        
    }
    
    func startUpdatingLocationWithCompletionHandler(_ completionHandler:((_ latitude:Double, _ longitude:Double, _ status:String, _ verboseMessage:String, _ error:String?)->())? = nil){
        
        self.completionHandler = completionHandler
        
        initLocationManager()
    }
    
    func stopUpdatingLocation(){
        
        if(autoUpdate){
            locationManager.stopUpdatingLocation()
        }else{
            locationManager.stopMonitoringSignificantLocationChanges()
        }
        
        
        //resetLatLon()
        if(!keepLastKnownLocation){
            resetLastKnownLatLon()
        }
    }
    
    fileprivate func initLocationManager() {
        
        // App might be unreliable if someone changes autoupdate status in between and stops it
        
        // Create a location manager object
        
        // locationManager.locationServicesEnabled
        
        // Set the delegate
        locationManager.delegate = self
        
        // Turn On Background Locations Updates
        locationManager.allowsBackgroundLocationUpdates = true
        
        // Set an accuracy level. The higher, the better for energy.
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        // Set Distance Filter to 50 Meters
        locationManager.distanceFilter = 44
        
        // Enable automatic pausing
        self.locationManager.pausesLocationUpdatesAutomatically = false
        
        // Specify the type of activity your app is currently performing
        //self.locationManager.activityType = CLActivityType.fitness
        //self.locationManager.activityType = CLActivityType.fitness
        
        setActiveMode(true)
        //        motionManager.startActivityUpdates(to: .main, withHandler: { [weak self] activity in
        //            self?.setActiveMode(activity?.cycling ?? false)
        //        })
        
        // Start monitoring for visits
        //self.locationManager.startMonitoringVisits()
        
        let Device = UIDevice.current
        
        let iosVersion = NSString(string: Device.systemVersion).doubleValue
        
        let iOS8 = iosVersion >= 8
        
        if iOS8 {
            locationManager.requestWhenInUseAuthorization() // add in plist NSLocationWhenInUseUsageDescription
            //locationManager.requestAlwaysAuthorization() // add in plist NSLocationAlwaysUsageDescription
            locationManager.startUpdatingLocation()
            locationManager.startMonitoringSignificantLocationChanges()
        }
        
        startLocationManger()
        
        
    }
    
    
    func setActiveMode(_ value: Bool) {
        if value {
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.distanceFilter = 44
            //locationManager.disallowDeferredLocationUpdates()
            if CLLocationManager.deferredLocationUpdatesAvailable() {
                DDLogVerbose("Setting up deferred location updating...")
                // If allowed, defer updates unless the location has changed
                // by more than 44m, or is more than 24 hours stale.
                locationManager.allowDeferredLocationUpdates(untilTraveled: 44,
                                                             timeout: 24.0 * 60.0 * 60.0)
            }
        } else {
            locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
            locationManager.distanceFilter = CLLocationDistanceMax
            locationManager.allowDeferredLocationUpdates(untilTraveled: CLLocationDistanceMax,
                                                         timeout: CLTimeIntervalMax)
        }
    }
    
    fileprivate func startLocationManger(){
        
        if(autoUpdate){
            
            locationManager.startUpdatingLocation()
        }else{
            
            locationManager.startMonitoringSignificantLocationChanges()
        }
        
        isRunning = true
        
    }
    
    
    fileprivate func stopLocationManger(){
        
        if(autoUpdate){
            
            locationManager.stopUpdatingLocation()
        }else{
            
            locationManager.stopMonitoringSignificantLocationChanges()
        }
        
        isRunning = false
    }
    
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        
        DDLogVerbose("Location manager failed: \(error.localizedDescription)")
        
        stopLocationManger()
        
        //resetLatLon()
        
        if(!keepLastKnownLocation){
            
            resetLastKnownLatLon()
        }
        
        var verbose = ""
        if showVerboseMessage {verbose = verboseMessage}
        completionHandler?(0.0, 0.0, locationStatus as String, verbose,error.localizedDescription)
        
        if ((delegate != nil) && (delegate?.responds(to: #selector(SLLocationManagerDelegate.locationManagerReceivedError(_:))))!){
            delegate?.locationManagerReceivedError!(error.localizedDescription as NSString)
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        // Process the received location update
        DDLogVerbose("Processing Recieved Location Updates")
        let arrayOfLocation = locations as NSArray
        let location = arrayOfLocation.lastObject as! CLLocation
        let coordLatLon = location.coordinate
        
        latitude  = coordLatLon.latitude
        longitude = coordLatLon.longitude
        
        latitude = latitude.truncate(places: 6)
        longitude = longitude.truncate(places: 6)
        
        latitudeAsString  = coordLatLon.latitude.description
        longitudeAsString = coordLatLon.longitude.description
        
        var verbose = ""
        
        if showVerboseMessage {verbose = verboseMessage}
        
        if(completionHandler != nil){
            completionHandler?(latitude, longitude, locationStatus as String,verbose, nil)
        }
        
        lastKnownLatitude = coordLatLon.latitude
        lastKnownLongitude = coordLatLon.longitude
        
        lastKnownLatitudeAsString = coordLatLon.latitude.description
        lastKnownLongitudeAsString = coordLatLon.longitude.description
        
        hasLastKnownLocation = true
        
        if (delegate != nil) {
            if((delegate?.responds(to: #selector(SLLocationManagerDelegate.locationFoundGetAsString(_:longitude:))))!){
                delegate?.locationFoundGetAsString!(latitudeAsString as NSString,longitude:longitudeAsString as NSString)
            }
            if((delegate?.responds(to: #selector(SLLocationManagerDelegate.locationFound(_:longitude:))))!){
                delegate?.locationFound(latitude,longitude:longitude)
            }
        }
        
        locationManager.allowDeferredLocationUpdates(untilTraveled: CLLocationDistanceMax, timeout: CLTimeIntervalMax)
        
        // Stop location updates
        //self.locationManager.stopUpdatingLocation()
    }
    
    
    func locationManager(_ manager: CLLocationManager,
                         didChangeAuthorization status: CLAuthorizationStatus) {   switch status {
        
    case .restricted, .denied, .authorizedWhenInUse:
        SLNotificationsManager.sharedInstance.GPSOff(message: "Location is turned off. App will be unable to track to your device(s).", body: "", type: 1)
        enableMyWhenInUseFeatures()
        escalateLocationServiceAuthorization()
        // Disable your app's location features
        //disableMyLocationBasedFeatures()
        /*let alertController = UIAlertController(
         title: "Background Location Access Disabled",
         message: "In order to be notified about trackers near you, please open this app's settings and set location access to 'Always'.",
         preferredStyle: .alert)
         
         let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
         alertController.addAction(cancelAction)
         
         let openAction = UIAlertAction(title: "Open Settings", style: .default) { (action) in
         if let url = NSURL(string:UIApplicationOpenSettingsURLString) {
         UIApplication.shared.openURL(url as URL)
         }
         }
         alertController.addAction(openAction)
         // Show Blocker UI
         //self.presentViewController(alertController, animated: true, completion: nil)*/
        //break
        //    case :
        //        // Enable only your app's when-in-use features.
        break
        
    case .authorizedAlways:
        // Enable any of your app's location services.
        enableMyAlwaysFeatures()
        break
        
    case .notDetermined:
        manager.requestWhenInUseAuthorization()
        break
        }
    }
    
    func reverseGeocodeLocationWithLatLon(latitude:Double, longitude: Double,onReverseGeocodingCompletionHandler:LMReverseGeocodeCompletionHandler){
        
        let location:CLLocation = CLLocation(latitude:latitude, longitude: longitude)
        
        reverseGeocodeLocationWithCoordinates(location,onReverseGeocodingCompletionHandler: onReverseGeocodingCompletionHandler)
        
    }
    
    func reverseGeocodeLocationWithCoordinates(_ coord:CLLocation, onReverseGeocodingCompletionHandler:LMReverseGeocodeCompletionHandler){
        
        self.reverseGeocodingCompletionHandler = onReverseGeocodingCompletionHandler
        
        reverseGocode(coord)
    }
    
    fileprivate func reverseGocode(_ location:CLLocation){
        
        let geocoder: CLGeocoder = CLGeocoder()
        
        geocoder.reverseGeocodeLocation(location, completionHandler: {(placemarks, error)->Void in
            
            if (error != nil) {
                self.reverseGeocodingCompletionHandler!(nil,nil, error!.localizedDescription)
                
            }
            else{
                
                if let placemark = placemarks?.first {
                    let address = AddressParser()
                    address.parseAppleLocationData(placemark)
                    let addressDict = address.getAddressDictionary()
                    self.reverseGeocodingCompletionHandler!(addressDict,placemark,nil)
                }
                else {
                    self.reverseGeocodingCompletionHandler!(nil,nil,"No Placemarks Found!")
                    return
                }
            }
            
        })
    }
    
    
    
    func geocodeAddressString(address:NSString, onGeocodingCompletionHandler:LMGeocodeCompletionHandler){
        self.geocodingCompletionHandler = onGeocodingCompletionHandler
        geoCodeAddress(address)
    }
    
    fileprivate func geoCodeAddress(_ address:NSString) {
        
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address as String, completionHandler: {(placemarks: [CLPlacemark]?, error: NSError?) -> Void in
            if (error != nil) {
                self.geocodingCompletionHandler!(nil,nil,error!.localizedDescription)
            } else {
                
                if let placemark = placemarks?.first {
                    
                    let address = AddressParser()
                    address.parseAppleLocationData(placemark)
                    let addressDict = address.getAddressDictionary()
                    self.geocodingCompletionHandler!(addressDict,placemark,nil)
                } else {
                    self.geocodingCompletionHandler!(nil,nil,"invalid address: \(address)")
                }
            }
            } as! CLGeocodeCompletionHandler)
    }
    
    
    func geocodeUsingGoogleAddressString(address:String, onGeocodingCompletionHandler:LMGeocodeCompletionHandler){
        
        self.geocodingCompletionHandler = onGeocodingCompletionHandler
        
        geoCodeUsignGoogleAddress(address)
    }
    
    
    fileprivate func geoCodeUsignGoogleAddress(_ address:String){
        let APIKey = "AIzaSyABMxBdDrJs3FlpQRHkXucFFvgzNCjdLmE"
        var urlString = "https://maps.googleapis.com/maps/api/geocode/json?address=\(address)&key=\(APIKey)&sensor=true"
        
        urlString = urlString.urlEncoded //addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)! as NSString
        
        performOperationForURL(urlString, type: GeoCodingType.geocoding)
        
    }
    
    public func reverseGeocodeLocationUsingGoogleWithLatLon(latitude:Double, longitude: Double,onReverseGeocodingCompletionHandler:LMReverseGeocodeCompletionHandler){
        
        self.reverseGeocodingCompletionHandler = onReverseGeocodingCompletionHandler
        
        reverseGocodeUsingGoogle(latitude: latitude, longitude: longitude)
        
    }
    
    func reverseGeocodeLocationUsingGoogleWithCoordinates(_ coord:CLLocation, onReverseGeocodingCompletionHandler:LMReverseGeocodeCompletionHandler){
        
        reverseGeocodeLocationUsingGoogleWithLatLon(latitude: coord.coordinate.latitude, longitude: coord.coordinate.longitude, onReverseGeocodingCompletionHandler: onReverseGeocodingCompletionHandler)
        
    }
    
    fileprivate func reverseGocodeUsingGoogle(latitude:Double, longitude: Double){
        let APIKey = "AIzaSyABMxBdDrJs3FlpQRHkXucFFvgzNCjdLmE"
        var urlString = "https://maps.googleapis.com/maps/api/geocode/json?latlng=\(latitude),\(longitude)&key=\(APIKey)&sensor=true"
        
        urlString = urlString.urlEncoded //addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)! as NSString
        
        performOperationForURL(urlString, type: GeoCodingType.reverseGeocoding)
        
    }
    
    fileprivate func performOperationForURL(_ urlString:String,type:GeoCodingType){
        
        let url:URL? = URL(string:urlString as String)
        
        let request:URLRequest = URLRequest(url:url!)
        
        let task = URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
            
            if(error != nil){
                
                self.setCompletionHandler(responseInfo:nil, placemark:nil, error:error!.localizedDescription, type:type)
                
            }else{
                
                let kStatus = "status"
                let kOK = "ok"
                let kZeroResults = "ZERO_RESULTS"
                let kAPILimit = "OVER_QUERY_LIMIT"
                let kRequestDenied = "REQUEST_DENIED"
                let kInvalidRequest = "INVALID_REQUEST"
                let kInvalidInput =  "Invalid Input"
                
                //let dataAsString: NSString? = NSString(data: data!, encoding: NSUTF8StringEncoding)
                
                
                let jsonResult: NSDictionary = (try! JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.mutableContainers)) as! NSDictionary
                
                var status = jsonResult.value(forKey: kStatus) as! NSString
                status = status.lowercased as NSString
                
                if(status.isEqual(to: kOK)){
                    
                    let address = AddressParser()
                    
                    address.parseGoogleLocationData(jsonResult)
                    
                    let addressDict = address.getAddressDictionary()
                    let placemark:CLPlacemark = address.getPlacemark()
                    
                    self.setCompletionHandler(responseInfo:addressDict, placemark:placemark, error: nil, type:type)
                    
                }else if(!status.isEqual(to: kZeroResults) && !status.isEqual(to: kAPILimit) && !status.isEqual(to: kRequestDenied) && !status.isEqual(to: kInvalidRequest)){
                    
                    self.setCompletionHandler(responseInfo:nil, placemark:nil, error:kInvalidInput, type:type)
                    
                }
                    
                else{
                    
                    //status = (status.componentsSeparatedByString("_") as NSArray).componentsJoinedByString(" ").capitalizedString
                    self.setCompletionHandler(responseInfo:nil, placemark:nil, error:status as String, type:type)
                    
                }
                
            }
            
        })
        
        task.resume()
        
    }
    
    fileprivate func setCompletionHandler(responseInfo:NSDictionary?,placemark:CLPlacemark?, error:String?,type:GeoCodingType){
        
        if(type == GeoCodingType.geocoding){
            
            self.geocodingCompletionHandler!(responseInfo,placemark,error)
            
        }else{
            
            self.reverseGeocodingCompletionHandler!(responseInfo,placemark,error)
        }
    }
}


@objc public protocol SLLocationManagerDelegate : NSObjectProtocol
{
    func locationFound(_ latitude:Double, longitude:Double)
    @objc optional func locationFoundGetAsString(_ latitude:NSString, longitude:NSString)
    @objc optional func locationManagerStatus(_ status:NSString)
    @objc optional func locationManagerReceivedError(_ error:NSString)
    @objc optional func locationManagerVerboseMessage(_ message:NSString)
}

private class AddressParser: NSObject{
    
    fileprivate var latitude = NSString()
    fileprivate var longitude  = NSString()
    fileprivate var streetNumber = NSString()
    fileprivate var route = NSString()
    fileprivate var locality = NSString()
    fileprivate var subLocality = NSString()
    fileprivate var formattedAddress = NSString()
    fileprivate var administrativeArea = NSString()
    fileprivate var administrativeAreaCode = NSString()
    fileprivate var subAdministrativeArea = NSString()
    fileprivate var postalCode = NSString()
    fileprivate var country = NSString()
    fileprivate var subThoroughfare = NSString()
    fileprivate var thoroughfare = NSString()
    fileprivate var ISOcountryCode = NSString()
    fileprivate var state = NSString()
    
    
    override init(){
        super.init()
    }
    
    fileprivate func getAddressDictionary()-> NSDictionary{
        
        let addressDict = NSMutableDictionary()
        
        addressDict.setValue(latitude, forKey: "latitude")
        addressDict.setValue(longitude, forKey: "longitude")
        addressDict.setValue(streetNumber, forKey: "streetNumber")
        addressDict.setValue(locality, forKey: "locality")
        addressDict.setValue(subLocality, forKey: "subLocality")
        addressDict.setValue(administrativeArea, forKey: "administrativeArea")
        addressDict.setValue(postalCode, forKey: "postalCode")
        addressDict.setValue(country, forKey: "country")
        addressDict.setValue(formattedAddress, forKey: "formattedAddress")
        
        return addressDict
    }
    
    
    fileprivate func parseAppleLocationData(_ placemark:CLPlacemark){
        
        let addressLines = placemark.addressDictionary!["FormattedAddressLines"] as! NSArray
        
        //self.streetNumber = placemark.subThoroughfare ? placemark.subThoroughfare : ""
        self.streetNumber = (placemark.thoroughfare != nil ? placemark.thoroughfare : "")! as NSString
        self.locality = (placemark.locality != nil ? placemark.locality : "")! as NSString
        self.postalCode = (placemark.postalCode != nil ? placemark.postalCode : "")! as NSString
        self.subLocality = (placemark.subLocality != nil ? placemark.subLocality : "")! as NSString
        self.administrativeArea = (placemark.administrativeArea != nil ? placemark.administrativeArea : "")! as NSString
        self.country = (placemark.country != nil ?  placemark.country : "")! as NSString
        self.longitude = placemark.location!.coordinate.longitude.description as NSString;
        self.latitude = placemark.location!.coordinate.latitude.description as NSString
        if(addressLines.count>0){
            self.formattedAddress = addressLines.componentsJoined(by: ", ") as NSString}
        else{
            self.formattedAddress = ""
        }
    }
    
    
    fileprivate func parseGoogleLocationData(_ resultDict:NSDictionary){
        
        let locationDict = (resultDict.value(forKey: "results") as! NSArray).firstObject as! NSDictionary
        
        let formattedAddrs = locationDict.object(forKey: "formatted_address") as! NSString
        
        let geometry = locationDict.object(forKey: "geometry") as! NSDictionary
        let location = geometry.object(forKey: "location") as! NSDictionary
        let lat = location.object(forKey: "lat") as! Double
        let lng = location.object(forKey: "lng") as! Double
        self.latitude = lat.description as NSString
        self.longitude = lng.description as NSString
        
        let addressComponents = locationDict.object(forKey: "address_components") as! NSArray
        
        self.subThoroughfare = component("street_number", inArray: addressComponents, ofType: "long_name")
        self.thoroughfare = component("route", inArray: addressComponents, ofType: "long_name")
        self.streetNumber = self.subThoroughfare
        self.locality = component("locality", inArray: addressComponents, ofType: "long_name")
        self.postalCode = component("postal_code", inArray: addressComponents, ofType: "long_name")
        self.route = component("route", inArray: addressComponents, ofType: "long_name")
        self.subLocality = component("subLocality", inArray: addressComponents, ofType: "long_name")
        self.administrativeArea = component("administrative_area_level_1", inArray: addressComponents, ofType: "long_name")
        self.administrativeAreaCode = component("administrative_area_level_1", inArray: addressComponents, ofType: "short_name")
        self.subAdministrativeArea = component("administrative_area_level_2", inArray: addressComponents, ofType: "long_name")
        self.country =  component("country", inArray: addressComponents, ofType: "long_name")
        self.ISOcountryCode =  component("country", inArray: addressComponents, ofType: "short_name")
        self.formattedAddress = formattedAddrs;
        
    }
    
    fileprivate func component(_ component:NSString,inArray:NSArray,ofType:NSString) -> NSString{
        let index = inArray.indexOfObject(passingTest:) {obj, idx, stop in
            
            let objDict:NSDictionary = obj as! NSDictionary
            let types:NSArray = objDict.object(forKey: "types") as! NSArray
            let type = types.firstObject as! NSString
            return type.isEqual(to: component as String)
        }
        
        if (index == NSNotFound){
            
            return ""
        }
        
        if (index >= inArray.count){
            return ""
        }
        
        let type = ((inArray.object(at: index) as! NSDictionary).value(forKey: ofType as String)!) as! NSString
        
        if (type.length > 0){
            
            return type
        }
        return ""
        
    }
    
    fileprivate func getPlacemark() -> CLPlacemark{
        
        var addressDict = [String : AnyObject]()
        
        let formattedAddressArray = self.formattedAddress.components(separatedBy: ", ") as Array
        
        let kSubAdministrativeArea = "SubAdministrativeArea"
        let kSubLocality           = "SubLocality"
        let kState                 = "State"
        let kStreet                = "Street"
        let kThoroughfare          = "Thoroughfare"
        let kFormattedAddressLines = "FormattedAddressLines"
        let kSubThoroughfare       = "SubThoroughfare"
        let kPostCodeExtension     = "PostCodeExtension"
        let kCity                  = "City"
        let kZIP                   = "ZIP"
        let kCountry               = "Country"
        let kCountryCode           = "CountryCode"
        
        addressDict[kSubAdministrativeArea] = self.subAdministrativeArea
        addressDict[kSubLocality] = self.subLocality as NSString
        addressDict[kState] = self.administrativeAreaCode
        
        addressDict[kStreet] = formattedAddressArray.first! as NSString
        addressDict[kThoroughfare] = self.thoroughfare
        addressDict[kFormattedAddressLines] = formattedAddressArray as AnyObject?
        addressDict[kSubThoroughfare] = self.subThoroughfare
        addressDict[kPostCodeExtension] = "" as AnyObject?
        addressDict[kCity] = self.locality
        
        addressDict[kZIP] = self.postalCode
        addressDict[kCountry] = self.country
        addressDict[kCountryCode] = self.ISOcountryCode
        
        let lat = self.latitude.doubleValue
        let lng = self.longitude.doubleValue
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        
        let placemark = MKPlacemark(coordinate: coordinate, addressDictionary: addressDict as [String : AnyObject]?)
        
        return (placemark as CLPlacemark)
        
    }
}

// MARK:- Efficiently Monitoring Location Updates

extension SLLocationManager {
    
    public func getQuickLocationUpdate() {
        // Request location authorization
        DDLogVerbose("getQuickLocationUpdate called")
        //self.locationManager.requestWhenInUseAuthorization()
        // Request a location update
        self.locationManager.requestLocation()
        // Note: requestLocation may timeout and produce an error if authorization has not yet been granted by the user
    }
    
    func stopVisitMonitoring() {
        self.locationManager.stopMonitoringVisits()
    }
    
    public func locationManager(manager: CLLocationManager, didVisit visit: CLVisit!) {
        // Perform location-based activity
        DDLogVerbose("Visit: \(String(describing: visit))")
        // I find that sending this to a UILocalNotification is handy for debugging
    }
    
    public func enableLocationServices() {
        DDLogVerbose("enableLocationServices called")
        locationManager.delegate = self
        
        switch CLLocationManager.authorizationStatus() {
        case .notDetermined:
            // Request when-in-use authorization initially
            locationManager.requestWhenInUseAuthorization()
            break
            
        case .restricted, .denied:
            // Disable location features
            locationManager.requestWhenInUseAuthorization()
            disableMyLocationBasedFeatures()
            break
            
        case .authorizedWhenInUse:
            // Enable basic location features
            enableMyWhenInUseFeatures()
            break
            
        case .authorizedAlways:
            // Enable any of your app's location features
            enableMyAlwaysFeatures()
            break
        }
    }
    
    public func escalateLocationServiceAuthorization() {
        // Escalate only when the authorization is set to when-in-use
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            locationManager.requestAlwaysAuthorization()
        }
    }
    
    func disableMyLocationBasedFeatures() {
        
        DDLogVerbose("disableMyLocationBasedFeatures called")
        if (!locationStatus.isEqual(to: "Denied access")) {
            
            var verbose = ""
            if showVerboseMessage {
                verbose = verboseMessage
                if ((delegate != nil) && (delegate?.responds(to: #selector(SLLocationManagerDelegate.locationManagerVerboseMessage(_:))))!){
                    delegate?.locationManagerVerboseMessage!(verbose as NSString)
                }
            }
            if(completionHandler != nil){
                completionHandler?(latitude, longitude, locationStatus as String, verbose,nil)
            }
        }
    }
    
    func enableMyWhenInUseFeatures() {
        DDLogVerbose("enableMyWhenInUseFeatures called")
        getQuickLocationUpdate()
        if ((delegate != nil) && (delegate?.responds(to: #selector(SLLocationManagerDelegate.locationManagerStatus(_:))))!){
            delegate?.locationManagerStatus!(locationStatus)
        }
    }
    
    func enableMyAlwaysFeatures() {
        // Mandatory for IOS 11 and Up
        DDLogVerbose("enableMyAlwaysFeatures called")
        startLocationManger()
        //resetLatLon()
        if ((delegate != nil) && (delegate?.responds(to: #selector(SLLocationManagerDelegate.locationManagerStatus(_:))))!){
            delegate?.locationManagerStatus!(locationStatus)
        }
        SLSensorManager.sharedInstance.startAutoConnectTimer()
    }
    
    public func startMonitoringItem(_ item: TrackerDevice) {
        // DDLogVerbose("Started Monitoring beacons")
        let beaconRegion = item.asBeaconRegion()
        beaconRegion.notifyEntryStateOnDisplay = true
        beaconRegion.notifyOnExit = false
        beaconRegion.notifyOnEntry = true
        locationManager.startMonitoring(for: beaconRegion)
    }
    
    public func stopMonitoringItem(_ item: TrackerDevice) {
        //DDLogVerbose("Stopped Monitoring beacons")
        let beaconRegion = item.asBeaconRegion()
        locationManager.stopMonitoring(for: beaconRegion)
        //locationManager.stopRangingBeacons(in: beaconRegion)
    }
}

// Beacon Region Monitoring Methods

extension SLLocationManager {
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        DDLogVerbose("didEnterRegion called \(region.identifier)")
        if region is CLBeaconRegion {
            // Start ranging only if the feature is available.
            if CLLocationManager.isRangingAvailable() {
                manager.startRangingBeacons(in: region as! CLBeaconRegion)
                // Store the beacon so that ranging can be stopped on demand.
                //beaconsToRange.append(region as! CLBeaconRegion)
            }
        }
        //NotificationsManager.sharedInstance.scheduleLocalNotification(message: "\(region.identifier) didEnterRegion", body: "")
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        DDLogVerbose("didExitRegion called \(region.identifier)")
        //NotificationsManager.sharedInstance.scheduleLocalNotification(message: "\(region.identifier) didExitRegion", body: "")
    }
    
    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        DDLogVerbose("didStartMonitoringFor called \(region.identifier)")
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        // DDLogVerbose("Failed monitoring region: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        switch (state) {
        case CLRegionState.inside:
            //DDLogVerbose("didDetermineState region: INSIDE \(region.identifier)")
            //NotificationsManager.sharedInstance.scheduleLocalNotification(message: "\(region.identifier) didDetermineState - INSIDE", body: "")
            break
        case CLRegionState.outside:
            //DDLogVerbose("didDetermineState region: OUTSIDE \(region.identifier)")
            //NotificationsManager.sharedInstance.scheduleLocalNotification(message: "\(region.identifier) didDetermineState - OUTSIDE", body: "")
            break
        case CLRegionState.unknown:
            //DDLogVerbose("didDetermineState region: UNKNWON \(region.identifier)")
            break
            //default:
            //DDLogVerbose("didDetermineState region: Can not determine State \(region.identifier)")
            //    break;
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion) {
        
        //DDLogVerbose("didRangeBeacons method called Beacon count - \(beacons.count)")
        
        if beacons.count > 0 {
            //DDLogVerbose("Beacon Found")
            //SensorManager.sharedInstance.scannerState = .idle
            //SensorManager.sharedInstance.scannerState = .aggressiveScan
            let nearestBeacon = beacons.first!
            //let major = CLBeaconMajorValue(truncating: nearestBeacon.major)
            //let minor = CLBeaconMinorValue(truncating: nearestBeacon.minor)
            //print("Major:- \(major)")
            //print("Minor:- \(minor)")
            
            switch nearestBeacon.proximity {
            case .near, .immediate:
                // Display information about the relevant exhibit.
                // displayInformationAboutExhibit(major: major, minor: minor)
                //DDLogVerbose("Beacon \(region.identifier) is Nearby | Major \(major) | Minor \(minor)")
                //NotificationsManager.sharedInstance.scheduleLocalNotification(message: "\(region.identifier) Beacon nearby", body: "")
                break
            case .far:
                //DDLogVerbose("Beacon \(region.identifier) is Far away")
                // NotificationsManager.sharedInstance.scheduleLocalNotification(message: "\(region.identifier) Beacon is far away", body: "")
                break
            default:
                // Dismiss exhibit information, if it is displayed.
                //DDLogVerbose("Can not determine proximity for Beacon \(region.identifier)")
                //dismissExhibit(major: major, minor: minor)
                break
            }
        }
    }
}

internal extension String {
    
    var urlEncoded: String {
        return self.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!
    }
}
