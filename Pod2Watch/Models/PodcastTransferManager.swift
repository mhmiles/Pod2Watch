//
//  PodcastTransferManager.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 3/30/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import UIKit
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
    
    let fileManager = FileManager.default

    if fileManager.fileExists(atPath: outputURL.absoluteString) {
      try? fileManager.removeItem(at: outputURL)
    }
    
    let request: NSFetchRequest<TransferredPodcast> = TransferredPodcast.fetchRequest()
    request.predicate = NSPredicate(format: "title == %@", episode.podcast!.title!)
    let context = PersistentContainer.shared.viewContext
    
    let transferredPodcast = try! context.fetch(request).first ?? TransferredPodcast(episode.podcast!, context: context)
    let transferredEpisode = TransferredEpisode(episode)
    transferredPodcast.addToEpisodes(transferredEpisode)
    transferredEpisode.fileURL = outputURL
    
    PersistentContainer.saveContext()

    exporter.exportAsynchronously(completionHandler: handlePendingTransfers)
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
      var metadata: [String: Any] = [
        "type": "episode",
        "persistentID": episode.persistentID,
        "podcastTitle": episode.podcastTitle ?? "",
        "episodeTitle": episode.episodeTitle ?? "",
        "playbackDuration": episode.playbackDuration
      ]
      
      if let artworkImage = episode.podcast?.artworkImage {
        metadata["artworkImage"] = UIImageJPEGRepresentation(artworkImage.shrunkTo(size: CGSize(width: 240, height: 240)), 1.0)
      }
      
      episode.transfer = session.transferFile(episode.fileURL!, metadata: metadata)
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
    session?.sendMessage(["type": MessageType.sendDeleteAll], replyHandler: nil)
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
    case MessageType.requestPending:
      handlePendingTransfers()
      
    case MessageType.confirmDeletes:
      guard let deletedPodcastIDs = message["payload"] as? [NSNumber] else {
        return
      }
      
      let context = PersistentContainer.shared.viewContext
      let request: NSFetchRequest<TransferredEpisode> = TransferredEpisode.fetchRequest()
      request.predicate = NSPredicate(format: "persistentID IN %@", deletedPodcastIDs)
      let deletedEpisodes = try! context.fetch(request)
      
      for episode in deletedEpisodes {
        context.delete(episode)
      }
      
      PersistentContainer.saveContext()
    
    case MessageType.confirmDeleteAll:
      shouldClearWatchStorage = false
      
      let context = PersistentContainer.shared.viewContext
      let request: NSFetchRequest<TransferredEpisode> = TransferredEpisode.fetchRequest()
      
      guard let episodes = try? context.fetch(request) else {
        return
      }
      
      let fileManager = FileManager.default
      
      context.perform {
        for episode in episodes {
          if let fileURL = episode.fileURL {
            try? fileManager.removeItem(at: fileURL)
          }

          context.delete(episode)
        }
      }

      PersistentContainer.saveContext()
      
    default:
      break
    }
  }
  
  func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
    if let error = error {
      print(error)
      
      let request: NSFetchRequest<TransferredEpisode> = TransferredEpisode.fetchRequest()
      request.predicate = NSPredicate(format: "persistentID == %@", fileTransfer.file.fileURL.deletingPathExtension().lastPathComponent)
      request.fetchLimit = 1
      
      guard let episode = (try? PersistentContainer.shared.viewContext.fetch(request))?.first else {
        return
      }
      
      episode.hasBegunTransfer = false

      return
    }
    
    guard let persistentID = fileTransfer.file.metadata?["persistentID"] as? Int64 else {
      fatalError("INVALID METADATA")
    }
    
    let request: NSFetchRequest<TransferredEpisode> = TransferredEpisode.fetchRequest()
    request.predicate = NSPredicate(format: "persistentID == %ld", persistentID)
    
    guard let episodes = try? PersistentContainer.shared.viewContext.fetch(request) else {
      return
    }
    
    let wasSuccessful = error == nil
    
    for episode in episodes {
      episode.isTransferred = wasSuccessful
      
      if wasSuccessful {
        try? FileManager.default.removeItem(at: episode.fileURL!)
      }
    }
    
    PersistentContainer.saveContext()
  }
  
  func sessionReachabilityDidChange(_ session: WCSession) {
  }
  
  func sessionDidBecomeInactive(_ session: WCSession) {
  }
  
  func sessionDidDeactivate(_ session: WCSession) {
  }
}
