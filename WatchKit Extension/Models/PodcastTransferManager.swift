//
//  PodcastTransferManager.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 5/3/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import UIKit
import CoreData
import WatchConnectivity

private let saveDirectoryURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.hollingsware.pod2watch")!.appendingPathComponent("Episodes", isDirectory: true)

class PodcastTransferManager: NSObject {
  static let shared = PodcastTransferManager()
  
  override init() {
    super.init()
    
    _ = session
  }
  
  lazy var session: WCSession = {
    let session = WCSession.default()
    session.delegate = self
    session.activate()
    
    return session
  }()
  
  func requestPending() {
    session.sendMessage(["type": MessageType.requestPending], replyHandler: nil)
  }
  
  func deletePodcast(_ episode: Episode) {
    deletePodcasts(persistentIDs: [episode.persistentID])
  }
  
  
  fileprivate func deletePodcasts(persistentIDs: [Int64]) {
    let episodes = Episode.existing(persistentIDs: persistentIDs)
    AudioPlayer.shared.removeFromQueue(episodes: episodes)
    
    for episode in episodes {
      try? FileManager.default.removeItem(at: episode.fileURL)
      
      PersistentContainer.shared.viewContext.delete(episode)
    }
    
    PersistentContainer.saveContext()
    
    let message: [String: Any] = [
      "type": MessageType.confirmDeletes,
      "payload": persistentIDs
    ]
    
    session.sendMessage(message, replyHandler: nil) { (error) in
      print(error)
    }
  }
  
  func deleteAllPodcasts() {
    let context = PersistentContainer.shared.viewContext
    
    context.perform {
      for episode in Episode.all() {
        context.delete(episode)
      }
    }
    
    PersistentContainer.saveContext()
    
    let fileManager = FileManager.default
    try? fileManager.contentsOfDirectory(at: saveDirectoryURL,
                                         includingPropertiesForKeys: nil).forEach { try? fileManager.removeItem(at: $0) }
    
    session.sendMessage(["type": MessageType.confirmDeleteAll], replyHandler: nil)
  }
  
  func requestArtwork(podcast: Podcast) {
    let message = [
      "type": MessageType.requestArtwork,
      "title": podcast.title
    ]
    
    session.sendMessage(message, replyHandler: { metadata in
      podcast.artworkImage = UIImage(data: metadata["artwork"] as! Data)
    })
  }
  
  
  fileprivate func requestDeletes() {
    let message = ["type": MessageType.requestDeletes]
    
    session.sendMessage(message, replyHandler: nil) { (error) in
      print(error)
    }
  }
}

//MARK: - WCSessionDelegate

extension PodcastTransferManager: WCSessionDelegate {
  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    switch activationState {
    case .activated:
      requestDeletes()
      
    default:
      break
    }
  }
  
  func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
    guard let messageType = message["type"] as? String else {
      return
    }
    
    switch messageType {
    case MessageType.sendDeletes:
      guard let persistentIDsToDelete = message["payload"] as? [Int64] else {
        return
      }
      
      deletePodcasts(persistentIDs: persistentIDsToDelete)
      
    case MessageType.sendDeleteAll:
      deleteAllPodcasts()
      
    default:
      break
    }
  }
  
  func session(_ session: WCSession, didReceive file: WCSessionFile) {
    guard let type  = file.metadata?["type"] as? String else {
      fatalError("No metadata type")
    }
    
    let context = PersistentContainer.shared.viewContext
    
    switch type {
    case MessageType.sendEpisode:
      let fileManager = FileManager.default
      
      if fileManager.fileExists(atPath: saveDirectoryURL.absoluteString) == false {
        try? fileManager.createDirectory(at: saveDirectoryURL,
                                         withIntermediateDirectories: false,
                                         attributes: nil)
      }
      
      let saveURL = saveDirectoryURL.appendingPathComponent(file.fileURL.lastPathComponent)
      
      if fileManager.fileExists(atPath: saveURL.absoluteString) {
        do {
          try fileManager.removeItem(at: saveURL)
        } catch let error {
          print(error)
        }
      }
      
      do {
        try fileManager.moveItem(at: file.fileURL, to: saveURL)
      } catch let error {
        print(error)
      }
      
      guard let metadata = file.metadata, let persistentID = metadata["persistentID"] as? Int64 else {
        print("NO METADATA")
        return
      }
      
      context.perform {
        let episode = Episode(context: context)
        
        episode.persistentID = persistentID
        episode.title = metadata["episodeTitle"] as? String
        episode.playbackDuration = metadata["playbackDuration"] as? Double ?? 0
        episode.fileURL = saveURL
        
        let podcastTitle = metadata["podcastTitle"] as! String
        let podcast = Podcast.existing(title: podcastTitle) ?? Podcast(title: podcastTitle, context: context)
        podcast.addToEpisodes(episode)
      }
      
    case MessageType.sendArtwork:
      guard let title = file.metadata?["title"] as? String else {
        fatalError("No artwork title")
      }

      if let podcast = Podcast.existing(title: title),
        let artworkData = FileManager.default.contents(atPath: file.fileURL.absoluteString) {
        podcast.artworkImage = UIImage(data: artworkData)
      }
      
    default:
      break
    }
    
    
    PersistentContainer.saveContext()
  }
}
