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
    session = WCSession.isSupported() ? WCSession.default : nil
    shouldClearWatchStorage = UserDefaults.standard.bool(forKey: "clear_watch_storage")
    
    super.init()
    
    session?.delegate = self
    session?.activate()
    
    NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification,
                                           object: nil,
                                           queue: OperationQueue.main) { [unowned self] _ in
                                            self.checkForDeleteAll()
    }
    
    NotificationCenter.default.addObserver(forName: .UIApplicationWillEnterForeground,
                                           object: nil,
                                           queue: OperationQueue.main) { [unowned self] _ in
                                            self.sendPendingDeletes()
    }
    
    NotificationCenter.default.addObserver(forName: .podcastLibraryDidReload,
                                           object: nil,
                                           queue: OperationQueue.main) {  [unowned self] _ in
                                            _ = self.handleAutoTransfers()
    }
  }
  
  func transfer(_ episode: LibraryEpisode, isAutoTransfer: Bool = false) {
    if let session = session, session.isWatchAppInstalled == false {
      if isAutoTransfer == false {
        showInstallAlert()
      }
      
      return
    }
    
    guard let assetURL = episode.assetURL else {
      return
    }
    
    let asset = AVAsset(url: assetURL)
    
    let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough)!
    exporter.outputFileType = AVFileType.mov
    
    let outputURL = URL(fileURLWithPath: "\(NSTemporaryDirectory())\(episode.persistentID).mov")
    exporter.outputURL = outputURL
    
    let artistMetadata = AVMutableMetadataItem()
    artistMetadata.keySpace = .iTunes
    artistMetadata.identifier = .iTunesMetadataArtist
    artistMetadata.value = (episode.podcast?.title ?? "") as NSString
    artistMetadata.key = AVMetadataKey.iTunesMetadataKeyArtist as NSString
    
    let titleMetadata = AVMutableMetadataItem()
    titleMetadata.keySpace = .iTunes
    titleMetadata.identifier = .iTunesMetadataSongName
    titleMetadata.value = (episode.title ?? "") as NSString
    titleMetadata.key = AVMetadataKey.iTunesMetadataKeySongName as NSString
    
    exporter.metadata = [artistMetadata, titleMetadata]
    
    let fileManager = FileManager.default
    
    if fileManager.fileExists(atPath: outputURL.path) {
      do {
        try fileManager.removeItem(at: outputURL)
      } catch let error {
        print(error)
      }
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
  
  private func showInstallAlert() {
    guard let rootViewController = UIApplication.shared.keyWindow?.rootViewController else {
      return
    }
    
    let alertController = PodcastAlertController(title: "Watch App Not Installed",
                                                 message: "\nInstall the Pod2Watch watch app before syncing podcasts.",
                                                 preferredStyle: .alert)
    alertController.addAction(UIAlertAction(title: "OK",
                                            style: .cancel,
                                            handler: nil))
    
    rootViewController.present(alertController,
                               animated: true)
  }
  
  func sendPendingTransfers() {
    guard let session = session, session.activationState == .activated else {
      self.session?.activate()
      return
    }
    
    PersistentContainer.shared.viewContext.perform {
      for episode in TransferredEpisode.pendingTransfers() {
        let metadata: [String: Any] = [
          "type": MessageType.sendEpisode,
          "persistentID": episode.persistentID,
          "podcastTitle": episode.podcast?.title ?? "",
          "episodeTitle": episode.title ?? "",
          "playbackDuration": episode.playbackDuration
        ]
        
        let message: [String: Any] = [
          "type": MessageType.sendTransferBegin,
          "payload": metadata
        ]
        
        session.sendMessage(message, replyHandler: nil, errorHandler: nil)
        episode.transfer = session.transferFile(episode.fileURL!, metadata: metadata)
        episode.hasBegunTransfer = true
      }
      
      PersistentContainer.saveContext()
    }
  }
  
  func sendSortOrder() {
    guard let session = session, session.isReachable else {
      return
    }
    
    var payload = [Int64: Int16]()
    for episode in TransferredEpisode.all() {
      payload[episode.persistentID] = episode.sortIndex
    }
    
    let message: [String: Any] = [
      "type": MessageType.sendSortOrder,
      "payload": payload
    ]
    
    session.sendMessage(message, replyHandler: nil, errorHandler: nil)
  }
  
  func checkForDeleteAll() {
    if UserDefaults.standard.bool(forKey: "clear_watch_storage") {
      shouldClearWatchStorage = true
    }
  }
  
  func delete(_ episode: TransferredEpisode) {
    if episode.hasBegunTransfer == true {
      
      if let transfer = episode.transfer {
        transfer.cancel()
      } else {
        session?.outstandingFileTransfers.forEach { (transfer) in
          if transfer.file.fileURL == episode.fileURL {
            transfer.cancel()
          }
        }
      }
    }
    
    episode.shouldDelete = true
    PersistentContainer.saveContext()
    
    sendPendingDeletes()
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
    guard let artworkImage = podcast.artworkImage else {
      return
    }
    
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
          do {
            try FileManager.default.removeItem(at: fileURL)
          } catch let error {
            print(error)
          }
        }
        
        episode.podcast?.removeFromEpisodes(episode)
        context.delete(episode)
      }
      
      PersistentContainer.saveContext()
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

// MARK: - WCSessionDelegate

extension PodcastTransferManager: WCSessionDelegate {
  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    if session.isWatchAppInstalled == false {
      PersistentContainer.shared.reset()
      return
    }
    
    switch activationState {
    case .activated:
      if shouldClearWatchStorage {
        sendDeleteAll()
      } else {
        sendPendingDeletes()
        sendPendingTransfers()
        sendSortOrder()
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
      
      let context = PersistentContainer.shared.viewContext
      
      context.perform {
        for episode in TransferredEpisode.existing(persistentIDs: deletedPersistentIDs) {
          episode.podcast?.removeFromEpisodes(episode)
          context.delete(episode)
        }
        
        PersistentContainer.saveContext()
      }
      
      
    case MessageType.requestDeletes:
      sendPendingDeletes()
      
    case MessageType.confirmDeleteAll:
      handleConfirmDeleteAll()
      
    default:
      break
    }
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
    
    do {
      try FileManager.default.removeItem(at: fileTransfer.file.fileURL)
    } catch let error {
      print(error)
    }
    
    PersistentContainer.saveContext()
  }
  
  func sessionDidBecomeInactive(_ session: WCSession) {
  }
  
  func sessionDidDeactivate(_ session: WCSession) {
  }
}
