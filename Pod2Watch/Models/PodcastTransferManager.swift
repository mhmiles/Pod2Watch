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
  
  var shouldClearWatchStorage: Bool {
    didSet {
      if shouldClearWatchStorage {
        sendDeleteAll()
      } else {
        UserDefaults.standard.set(false, forKey: "clear_watch_storage")
        sendPendingTransfers()
      }
    }
  }
  
  override init() {
    session = WCSession.isSupported() ? WCSession.default() : nil
    shouldClearWatchStorage = UserDefaults.standard.bool(forKey: "clear_watch_storage")
    
    super.init()
    
    session?.delegate = self
    session?.activate()
    
    NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification,
                                           object: nil,
                                           queue: OperationQueue.main) { [unowned self] _ in
                                            self.checkForDeleteAll()
    }
    
    NotificationCenter.default.addObserver(forName: InMemoryContainer.PodcastLibraryDidReload,
                                           object: nil,
                                           queue: OperationQueue.main) {  [unowned self] _ in
                                            _ = self.handleAutoTransfers()
    }
  }
  
  func transfer(_ episode: LibraryEpisode, isAutoTransfer: Bool = false) {
    if let session = session, session.isWatchAppInstalled == false {
      let alertController = UIAlertController(title: "Watch App Not Installed", message: "The Pod2Watch Watch app is not installed.", preferredStyle: .alert)
      
      let watchAppURL = URL(string: "itms-watch://")!
      
      alertController.addAction(UIAlertAction(title: "OK", style: .cancel))
      
      if UIApplication.shared.canOpenURL(watchAppURL) {
        alertController.addAction(UIAlertAction(title: "Open Watch App", style: .default) { _ in
          UIApplication.shared.open(watchAppURL)
        })
      }
      
      UIApplication.shared.keyWindow?.rootViewController?.present(alertController, animated: true)
    }
    
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
    
    let context = PersistentContainer.shared.viewContext
    
    context.performAndWait {
      let transferredPodcast = TransferredPodcast.existing(title: episode.podcast!.title!) ?? TransferredPodcast(episode.podcast!)
      let transferredEpisode = TransferredEpisode(episode)
      transferredPodcast.addToEpisodes(transferredEpisode)
      transferredEpisode.fileURL = outputURL
      transferredEpisode.isAutoTransfer = isAutoTransfer
    }
    
    PersistentContainer.saveContext()
    
    exporter.exportAsynchronously(completionHandler: sendPendingTransfers)
  }
  
  func sendPendingTransfers() {
    guard let session = session, session.activationState == .activated else {
      self.session?.activate()
      return
    }
    
    for episode in TransferredEpisode.pendingTransfers() {
      let metadata: [String: Any] = [
        "type": MessageType.sendEpisode,
        "persistentID": episode.persistentID,
        "podcastTitle": episode.podcast?.title ?? "",
        "episodeTitle": episode.title ?? "",
        "playbackDuration": episode.playbackDuration
      ]
      
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
  
  func delete(_ episode: TransferredEpisode) {
    if episode.hasBegunTransfer == false,
      let transfer = session?.outstandingFileTransfers.first(where: { $0.file.metadata?["persistentID"] as? Int64 == episode.persistentID}) {
      transfer.cancel()
      
      PersistentContainer.shared.viewContext.delete(episode)
    } else {
      episode.shouldDelete = true
      
      if WCSession.default().isReachable {
        let message : [String: Any] = [
          "type": MessageType.sendDeletes,
          "payload": [episode.persistentID]
        ]
        
        session?.sendMessage(message, replyHandler: nil, errorHandler: { (error) in
          print(error)
        })
      }
    }
    
    PersistentContainer.saveContext()
  }
  
  func sendDeleteAll() {
    session?.sendMessage(["type": MessageType.sendDeleteAll], replyHandler: nil)
  }
  
  func sendPendingDeletes() {
    let episodesToDelete = TransferredEpisode.pendingDeletes()
    
    if episodesToDelete.count > 0 {
      let message: [String: Any] = [
        "type": MessageType.sendDeletes,
        "payload": episodesToDelete.map { $0.persistentID }
      ]
      
      session?.sendMessage(message, replyHandler: nil)
    }
  }
  
  func sendArtwork(_ podcast: TransferredPodcast) {
    if let artworkImage = podcast.artworkImage {
      
      let filePath = NSTemporaryDirectory() + podcast.title.forFileName + ".jpg"
      FileManager.default.createFile(atPath: filePath,
                                     contents: UIImageJPEGRepresentation(artworkImage, 1.0))
      
      let metadata = [
        "type": MessageType.sendArtwork,
        "title": podcast.title
      ]
      
      session?.transferFile(URL(string: filePath)!,
                            metadata: metadata)
    }
  }
  
  func handleConfirmDeleteAll() {
    shouldClearWatchStorage = false
    
    if let transfers = session?.outstandingFileTransfers {
      for transfer in transfers {
        transfer.cancel()
      }
    }
    
    let context = PersistentContainer.shared.viewContext

    context.perform {
      for episode in TransferredEpisode.all() {
        if let fileURL = episode.fileURL {
          try? FileManager.default.removeItem(at: fileURL)
        }
        
        context.delete(episode)
      }
    }
  }
  
  func handleAutoTransfers() -> Bool {
    var wasNewTransfer = false
    
    for podcast in TransferredPodcast.autoTransfers() {
      wasNewTransfer = handleAutoTransfer(podcast: podcast) || wasNewTransfer
    }
    
    if wasNewTransfer {
      sendPendingDeletes()
    }
    
    return wasNewTransfer
  }
  
  func handleAutoTransfer(podcast: TransferredPodcast) -> Bool {
    if podcast.isAutoTransferred == false {
      return false
    }
    
    guard let latestAutoSyncEpisode = LibraryEpisode.latestEpisode(title: podcast.title) else {
      return false
    }
    
    let latestAutoSyncEpisodeReleaseDate = (latestAutoSyncEpisode.releaseDate as Date?) ?? Date.distantPast
    
    if let lastAutoSyncDate = podcast.lastAutoSyncDate {
      if latestAutoSyncEpisodeReleaseDate > lastAutoSyncDate {
        let request: NSFetchRequest<TransferredEpisode> = TransferredEpisode.fetchRequest()
        request.predicate = NSPredicate(format: "podcast == %@ AND isAutoTransfer == YES", podcast)
        let episodes = try! PersistentContainer.shared.viewContext.fetch(request)
        
        for episode in episodes {
          episode.shouldDelete = true
        }
        
        transfer(latestAutoSyncEpisode, isAutoTransfer: true)
        podcast.lastAutoSyncDate = latestAutoSyncEpisodeReleaseDate
        
        return true
      }
      
      return false
    } else {
      transfer(latestAutoSyncEpisode, isAutoTransfer: true)
      podcast.lastAutoSyncDate = latestAutoSyncEpisodeReleaseDate
      
      return true
    }
  }
}

//MARK: - WCSessionDelegate

extension PodcastTransferManager: WCSessionDelegate {
  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    switch activationState {
    case .activated:
      if shouldClearWatchStorage {
        sendDeleteAll()
      } else {
        sendPendingTransfers()
      }
      
    case .inactive:
      break
      
    case .notActivated:
      break
    }
  }
  
  func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
    guard let messageType = message["type"] as? String else {
      return
    }
    
    switch messageType {
    case MessageType.requestPending:
      sendPendingTransfers()
      
    case MessageType.confirmDeletes:
      guard let deletedPersistentIDs = message["payload"] as? [Int64] else {
        return
      }
      
      for episode in TransferredEpisode.existing(persistentIDs: deletedPersistentIDs) {
        PersistentContainer.shared.viewContext.delete(episode)
      }
      
    case MessageType.requestDeletes:
      sendPendingDeletes()
      
    case MessageType.confirmDeleteAll:
      handleConfirmDeleteAll()
      
    default:
      break
    }
    
    PersistentContainer.saveContext()
  }
  
  
  func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
    guard let messageType = message["type"] as? String else {
      return
    }
    
    switch messageType {
    case MessageType.requestArtwork:
      if let podcast = TransferredPodcast.existing(title: message["title"] as! String) {
        if let artworkImage = podcast.artworkImage {
          let reply = ["artwork": UIImageJPEGRepresentation(artworkImage.shrunkTo(size: CGSize(width: 100, height: 100)), 1.0)!]
          replyHandler(reply)
        }
        
        sendArtwork(podcast)
      }
      
    default:
      break
    }
  }
  
  func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
    if let error = error {
      print(error)
      
      if fileTransfer.file.fileURL.pathExtension == "mov" {
        let persistentIDString = fileTransfer.file.fileURL.deletingPathExtension().lastPathComponent
        
        guard let persistentID = Int64(persistentIDString),
          let episode = TransferredEpisode.existing(persistentID: Int64(persistentID)  ) else {
            return
        }
        
        episode.hasBegunTransfer = false
      }
      return
    }
    
    guard let type  = fileTransfer.file.metadata?["type"] as? String else {
      fatalError("No metadata type")
    }
    
    switch type {
    case MessageType.sendEpisode:
      guard let persistentID = fileTransfer.file.metadata?["persistentID"] as? Int64 else {
        fatalError("INVALID METADATA")
      }
      
      guard let episode = TransferredEpisode.existing(persistentID: persistentID) else {
        return
      }
      
      episode.isTransferred = true
      
    default:
      break
    }
    
    try? FileManager.default.removeItem(at: fileTransfer.file.fileURL)
    
    PersistentContainer.saveContext()
  }
  
  func sessionDidBecomeInactive(_ session: WCSession) {
  }
  
  func sessionDidDeactivate(_ session: WCSession) {
  }
}
