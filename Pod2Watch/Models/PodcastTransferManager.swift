//
//  PodcastTransferManager.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 3/30/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import Foundation
import WatchConnectivity
import CoreData
import AVFoundation

class PodcastTransferManager: NSObject {
  static let shared = PodcastTransferManager()
  
  let session: WCSession?
  
  var shouldClearWatchStorage = false {
    didSet {
      if shouldClearWatchStorage {
        sendDeleteAll()
      } else {
        UserDefaults.standard.set(false, forKey: "clear_watch_storage")
        handlePendingTransfers()
      }
    }
  }
  
  override init() {
    session = WCSession.isSupported() ? WCSession.default() : nil
    
    super.init()
    
    session?.delegate = self
    session?.activate()
    
    checkForDeleteAll()
    
    NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification,
                                           object: nil,
                                           queue: OperationQueue.main) { [unowned self] _ in
                                            self.checkForDeleteAll()
    }
  }
  
  func transfer(_ episode: LibraryEpisode) {
    guard let assetURL = episode.assetURL else {
      return
    }
    
    let asset = AVAsset(url: assetURL)
    
    let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough)!
    exporter.outputFileType = AVFileTypeQuickTimeMovie
  
    let outputURL = URL(fileURLWithPath: "\(NSTemporaryDirectory())\(episode.persistentID).mov")
    exporter.outputURL = outputURL
    
    let request: NSFetchRequest<TransferredPodcast> = TransferredPodcast.fetchRequest()
    request.predicate = NSPredicate(format: "persistentID == %ld", episode.podcast!.persistentID)
    let context = PersistentContainer.shared.viewContext
    
    let transferredPodcast = try! context.fetch(request).first ?? TransferredPodcast(episode.podcast!, context: context)
    let transferredEpisode = TransferredEpisode(episode)
    transferredEpisode.podcast = transferredPodcast
    
    if let episodeTitle = episode.title as NSString? {
      let metadata = AVMutableMetadataItem()
      metadata.keySpace = AVMetadataKeySpaceCommon
      metadata.key = AVMetadataCommonKeyTitle as NSString
      metadata.value = episodeTitle
      
      exporter.metadata = [metadata]
    }

    exporter.exportAsynchronously {
      switch exporter.status {
      case .completed:
        transferredEpisode.fileURLString = outputURL.absoluteString
        self.handlePendingTransfers()
        
      default:
        print("Failed")
        
        if FileManager.default.fileExists(atPath: outputURL.absoluteString) {
          transferredEpisode.fileURLString = outputURL.absoluteString
          self.handlePendingTransfers()
        }
        break
      }
    }
  }
  
  func handlePendingTransfers() {
    guard let session = session, session.activationState == .activated else {
      self.session?.activate()
      return
    }
    
    let request: NSFetchRequest<TransferredEpisode> = TransferredEpisode.fetchRequest()
    request.predicate = NSPredicate(format: "hasBegunTransfer == NO")
    
    let pendingTransfers = try! PersistentContainer.shared.viewContext.fetch(request)
    
    for episode in pendingTransfers {
      let metadata: [String: Any] = [
        "podcastID": episode.persistentID,
        "podcastTitle": episode.podcastTitle ?? "",
        "episodeTitle": episode.episodeTitle ?? "",
        "playbackDuration": episode.playbackDuration
      ]
      
      episode.transfer = session.transferFile(episode.fileURL, metadata: metadata)
      episode.hasBegunTransfer = true
    }
    
    PersistentContainer.saveContext()
  }
  
  func checkForDeleteAll() {
    if UserDefaults.standard.bool(forKey: "clear_watch_storage") {
      shouldClearWatchStorage = true
    }
  }
  
  func sendDeleteAll() {
    let message = ["type": MessageType.sendDeleteAll]
    
    session?.sendMessage(message, replyHandler: { (reply) in
      guard let messageType = reply["type"] as? String else {
        fatalError()
      }
      
      if messageType == MessageType.confirmDeletes {
        self.shouldClearWatchStorage = false
        
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = TransferredEpisode.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        try! PersistentContainer.shared.viewContext.execute(deleteRequest)
        PersistentContainer.saveContext()
      }
    }, errorHandler: nil)
  }
}

extension PodcastTransferManager: WCSessionDelegate {
  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    switch activationState {
    case .activated:
      if shouldClearWatchStorage {
        sendDeleteAll()
      } else {
        handlePendingTransfers()
      }
      
    case .inactive:
      break
      
    case .notActivated:
      break
    }
  }

  func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
    guard let messageType = message["type"] as? String else {
      return
    }
    
    switch messageType {
    case MessageType.requestDeletes:
      let request: NSFetchRequest<TransferredEpisode> = TransferredEpisode.fetchRequest()
      request.predicate = NSPredicate(format: "shouldDelete == YES")
      
      let context = PersistentContainer.shared.viewContext
      
      guard let episodesToDelete = try? context.fetch(request), episodesToDelete.count > 0 else {
        return
      }
      
      let reply: [String: Any] = [
        "type": MessageType.sendDeletes,
        "payload": episodesToDelete.map { NSNumber(value: $0.persistentID) }
      ]
      
      replyHandler(reply)
      
    default:
      break
    }
  }
  
  func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
    guard let messageType = message["type"] as? String else {
      return
    }
    
    switch messageType {
    case MessageType.confirmDeletes:
      guard let deletedPodcastIDs = message["payload"] as? [NSNumber] else {
        return
      }
      
      let context = PersistentContainer.shared.viewContext
      let request: NSFetchRequest<TransferredEpisode> = TransferredEpisode.fetchRequest()
      request.predicate = NSPredicate(format: "podcastID IN %@", deletedPodcastIDs)
      let deletedEpisodes = try! context.fetch(request)
      
      for episode in deletedEpisodes {
        context.delete(episode)
      }
      
      PersistentContainer.saveContext()
      
    default:
      break
    }
  }
  
  func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
    if let error = error {
      print(error)
    } else if let podcastID = fileTransfer.file.metadata?["podcastID"] as? Int64 {
      let request: NSFetchRequest<TransferredEpisode> = TransferredEpisode.fetchRequest()
      request.predicate = NSPredicate(format: "podcastID == %@", NSNumber(value: podcastID))
      
      if let episodes = try? PersistentContainer.shared.viewContext.fetch(request) {
        for episode in episodes {
          episode.isTransferred = true
          
          try? FileManager.default.removeItem(at: episode.fileURL)
        }
        
        PersistentContainer.saveContext()
      }
    } else {
      print("Invalid metadata")
    }
  }
  
  func sessionDidBecomeInactive(_ session: WCSession) {
  }
  
  func sessionDidDeactivate(_ session: WCSession) {
  }
}
