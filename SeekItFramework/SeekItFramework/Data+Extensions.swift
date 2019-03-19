//
//  Data+Extensions.swift
//  SeekLib
//
//  Created by Jitendra Chamoli on 09/10/18.
//

import Foundation
import CommonCrypto

// Source: http://stackoverflow.com/a/35201226/2115352

extension Data {
    
    internal var hexString: String {
        let pointer = self.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> UnsafePointer<UInt8> in
            return bytes
        }
        let array = getByteArray(pointer)
        
        return array.reduce("") { (result, byte) -> String in
            result + String(format: "%02x", byte)
        }
    }
    
    fileprivate func getByteArray(_ pointer: UnsafePointer<UInt8>) -> [UInt8] {
        let buffer = UnsafeBufferPointer<UInt8>(start: pointer, count: count)
        return [UInt8](buffer)
    }
}

extension Data {
    var md5 : String {
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        _ =  self.withUnsafeBytes { bytes in
            CC_MD5(bytes, CC_LONG(self.count), &digest)
        }
        var digestHex = ""
        for index in 0..<Int(CC_MD5_DIGEST_LENGTH) {
            digestHex += String(format: "%02x", digest[index])
        }
        return digestHex
    }
}

extension Data {
    // Print Data as a string of bytes in hex, such as the common representation of APNs device tokens
    // See: http://stackoverflow.com/a/40031342/9849
    var hexByteString: String {
        return self.map { String(format: "%02.2hhx", $0) }.joined()
    }
}
