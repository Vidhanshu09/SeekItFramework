//
//  NetworkManager.swift
//  SeekLib
//
//  Created by Jitendra Chamoli on 09/10/18.
//

import Foundation
import Alamofire

public class NetworkManager {
    
    public static let sharedInstance = NetworkManager()
    
    public static let sessionManager: SessionManager = {
        let serverTrustPolicies: [String: ServerTrustPolicy] = [
            AppConstants.BASE_SERVER_IP(): .disableEvaluation
        ]
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 40
        //configuration.timeoutIntervalForRequest = 30
        //configuration.timeoutIntervalForResource = 30
        //configuration.httpCookieStorage = nil
        //configuration.requestCachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalAndRemoteCacheData
        //if #available(iOS 11.0, *) {
        //    configuration.waitsForConnectivity = true
        //}
        return Alamofire.SessionManager(
            configuration: configuration,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: serverTrustPolicies))
    }()
}
