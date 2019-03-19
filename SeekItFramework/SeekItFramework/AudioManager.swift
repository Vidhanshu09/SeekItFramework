//
//  AudioManager.swift
//  SeekLib
//
//  Created by Jitendra Chamoli on 09/10/18.
//

import Foundation
import Alamofire

public class AudioManager {
    
    public static let shared = AudioManager()
    private init() {}
    let networkManager = NetworkManager.sessionManager
    
    //MARK: - Audio Downloading
    
    public func getSaveFileUrl(fileName: String) -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let nameUrl = URL(string: fileName)
        let fileURL = documentsURL.appendingPathComponent((nameUrl?.lastPathComponent)!)
        NSLog(fileURL.absoluteString)
        return fileURL
    }
    
    //    func retrieveAudio(for url: String, completion: @escaping (UIImage) -> Void) -> Request {
    //        return networkManager.request(url, method: .get).responseImage { response in
    //            guard let image = response.result.value else { return }
    //            completion(image)
    //            //self.cache(image, for: url)
    //        }
    //    }
    
    public func retrieveAudio(for audioUrl: String) {
        
        let fileUrl = self.getSaveFileUrl(fileName: audioUrl)
        let destination: DownloadRequest.DownloadFileDestination = { _, _ in
            return (fileUrl, [.removePreviousFile, .createIntermediateDirectories])
        }
        networkManager.download(audioUrl, to:destination)
            .downloadProgress { (progress) in
                //self.progressLabel.text = (String)(progress.fractionCompleted)
                let progress = (String)(progress.fractionCompleted)
                print(progress)
            }
            .responseData { (data) in
                print("Audio Download Complete")
                if let url = data.destinationURL {
                    //print(url.absoluteString)
                    //print(url.relativePath)
                    
                    let lastPath = url.lastPathComponent
                    print("Downloaded at :- \(String(describing: lastPath))")
                    print("Recording Stored at \(String(describing: audioUrl))")
                    print(" *** Testing **** ")
                    
                    let audioRecord = AudioCache()
                    audioRecord.id = UUID().uuidString
                    audioRecord.localPath = lastPath
                    audioRecord.serverURL = audioUrl
                    DispatchQueue.main.async {
                        SLRealmManager.sharedInstance.writeAudioCache(audioInfo: audioRecord)
                    }
                    
                    /*let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                     let toURL = documentsDirectory.appendingPathComponent(url.lastPathComponent.replacingOccurrences(of: "mp3", with: "mp4"))
                     
                     print("renaming file \(url.absoluteString) to \(toURL) url \(url.absoluteString.replacingOccurrences(of: "mp3", with: "mp4"))")
                     
                     if FileManager.default.fileExists(atPath: toURL.path) {
                     print("Removing file at path as the file already exists")
                     do {
                     try FileManager.default.removeItem(at: toURL)
                     print("Removed Existing file successfully")
                     }
                     catch {
                     print(error.localizedDescription)
                     print("error renaming recording")
                     }
                     }
                     do {
                     try FileManager.default.moveItem(at: url, to: toURL)
                     TAAudioPlayer.sharedInstance.tempURL = toURL
                     //self.recordedAudioPath = toURL.absoluteString
                     let lastPath = toURL.lastPathComponent
                     print("Downloaded at :- \(String(describing: lastPath))")
                     print("Recording Stored at \(String(describing: audioUrl))")
                     print(" *** Testing **** ")
                     
                     let audioRecord = AudioCache()
                     audioRecord.id = UUID().uuidString
                     audioRecord.localPath = lastPath
                     audioRecord.serverURL = audioUrl
                     DispatchQueue.main.async {
                     RealmManager.sharedInstance.writeAudioCache(audioInfo: audioRecord)
                     }
                     } catch {
                     print(error.localizedDescription)
                     print("error renaming recording")
                     }*/
                }
        }
    }
}
