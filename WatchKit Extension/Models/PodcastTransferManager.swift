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
import Alamofire
import ReactiveSwift
import AlamofireImage

enum DownloadError: Error {
  case episodeExists
}

private let saveDirectoryURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.hollingsware.pod2watch")!.appendingPathComponent("Episodes", isDirectory: true)

class PodcastTransferManager: NSObject {
  static let shared = PodcastTransferManager()
  
  lazy var session: WCSession = {
    let session = WCSession.default
    session.delegate = self
    session.activate()
    
    return session
  }()
  
  override init() {
    super.init()
    
    _ = session
  }
  
  func delete(_ episode: Episode) {
    deleteEpisodes(persistentIDs: [episode.persistentID])
  }
  
  internal func sendWatchDownload(episode: DownloadEpisode, sortIndex: Int16) {
    let message: [String: Any] = [
      "type": MessageType.sendWatchDownload,
      "persistentID": episode.persistentID,
      "title": episode.title,
      "podcastTitle": episode.podcastTitle,
      "releaseDate": episode.releaseDate,
      "playbackDuration": episode.playbackDuration,
      "artworkURL": episode.artworkURL.absoluteString,
      "sortIndex": sortIndex
    ]
    
    session.sendMessage(message,
                        replyHandler: nil)
  }
  
  fileprivate func deleteEpisodes(persistentIDs: [Int64]) {
    let episodes = Episode.existing(persistentIDs: persistentIDs)
    AudioPlayer.shared.removeFromQueue(episodes: episodes)
    
    let context = PersistentContainer.shared.viewContext
    
    context.perform {
      for episode in episodes {
        episode.downloadRequest = nil
        
        if let fileURL = episode.fileURL {
          do {
            try FileManager.default.removeItem(at: fileURL)
          } catch let error {
            print(error)
          }
        }
        
        episode.podcast.removeFromEpisodes(episode)
        context.delete(episode)
      }
      
      PersistentContainer.saveContext()
    }
    
    let message: [String: Any] = [
      "type": MessageType.confirmDeletes,
      "payload": persistentIDs
    ]
    
    session.sendMessage(message, replyHandler: nil) { (error) in
      print(error)
    }
  }
  
  func deleteAllPodcasts() {
    AudioPlayer.shared.episodeQueue = nil
    
    let context = PersistentContainer.shared.viewContext
    
    context.perform {
      for episode in Episode.all() {
        episode.downloadRequest = nil
        episode.podcast.removeFromEpisodes(episode)
        context.delete(episode)
      }
      
      PersistentContainer.saveContext()
    }
    
    let fileManager = FileManager.default
    
    do {
      try fileManager.contentsOfDirectory(at: saveDirectoryURL,
                                          includingPropertiesForKeys: nil).forEach {
                                            try fileManager.removeItem(at: $0)
      }
    } catch let error {
      print(error)
    }
    
    session.sendMessage(["type": MessageType.confirmDeleteAll], replyHandler: nil)
  }
  
  func requestArtwork(podcast: Podcast) {
    if session.isReachable == false {
      return
    }
    
    let message = [
      "type": MessageType.requestArtwork,
      "title": podcast.title
    ]
    
    session.sendMessage(message, replyHandler: { metadata in
      podcast.artworkImage = UIImage(data: metadata["artwork"] as! Data)
    })
  }
  
  fileprivate func requestDeletes() {
    if session.isReachable == false {
      return
    }
    
    let message = ["type": MessageType.requestDeletes]
    
    session.sendMessage(message, replyHandler: nil) { (error) in
      print(error)
    }
  }
}

// MARK: - WCSessionDelegate

extension PodcastTransferManager: WCSessionDelegate {
  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    switch activationState {
    case .activated:
      break
      
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
      
      deleteEpisodes(persistentIDs: persistentIDsToDelete)
      
    case MessageType.sendDeleteAll:
      deleteAllPodcasts()
      
    case MessageType.sendTransferBegin:
      guard let metadata = message["payload"] as? [String: Any] else {
        print("NO METADATA")
        return
      }
      
      processMetadata(metadata)
      
    case MessageType.sendSortOrder:
      guard let payload = message["payload"] as? [Int64: Int16] else {
        print("NO METADATA")
        return
      }
      
      processSortOrder(payload)
      
    default:
      break
    }
  }
  
  private func processMetadata(_ metadata: [String: Any], fileURL: URL? = nil) {
    guard let persistentID = metadata["persistentID"] as? Int64 else {
      print("No Persistent ID")
      return
    }
    
    let context = PersistentContainer.shared.viewContext
    
    context.perform {
      let episode = Episode.existing(persistentIDs: [persistentID]).first ?? Episode(context: context)
      
      episode.persistentID = persistentID
      episode.title = metadata["episodeTitle"] as? String
      episode.playbackDuration = metadata["playbackDuration"] as? Double ?? 0
      episode.fileURL = fileURL
      
      if let sortIndex = metadata["sortIndex"] as? Int16 {
        episode.sortIndex = sortIndex
      }
      
      let podcastTitle = metadata["podcastTitle"] as! String
      let podcast = Podcast.existing(title: podcastTitle) ?? Podcast(title: podcastTitle, context: context)
      podcast.addToEpisodes(episode)
      
      PersistentContainer.saveContext()
    }
  }
  
  private func processSortOrder(_ sortOrder: [Int64: Int16]) {
        PersistentContainer.shared.viewContext.perform {
          let episodes = Episode.existing(persistentIDs: Array(sortOrder.keys))
          
          for episode in episodes {
            episode.sortIndex = sortOrder[episode.persistentID]!
          }
          
          PersistentContainer.saveContext()
    }

  }
  
  func session(_ session: WCSession, didReceive file: WCSessionFile) {
    guard let type  = file.metadata?["type"] as? String else {
      fatalError("No metadata type")
    }
    
    switch type {
    case MessageType.sendEpisode:
      let fileManager = FileManager.default
      let saveURL = saveDirectoryURL.appendingPathComponent(file.fileURL.lastPathComponent)
      
      do {
        if fileManager.fileExists(atPath: saveDirectoryURL.path) == false {
          try fileManager.createDirectory(at: saveDirectoryURL,
                                          withIntermediateDirectories: false,
                                          attributes: nil)
        }
        
        
        if fileManager.fileExists(atPath: saveURL.path) {
          try fileManager.removeItem(at: saveURL)
        }
        
        try fileManager.moveItem(at: file.fileURL, to: saveURL)
      } catch let error {
        print(error)
      }
      
      guard let metadata = file.metadata else {
        print("NO METADATA")
        return
      }
      
      processMetadata(metadata, fileURL: saveURL)
      
    case MessageType.sendArtwork:
      guard let title = file.metadata?["title"] as? String else {
        fatalError("No artwork title")
      }
      
      if let podcast = Podcast.existing(title: title),
        let artworkData = FileManager.default.contents(atPath: file.fileURL.path) {
        podcast.artworkImage = UIImage(data: artworkData)
      }
      
      PersistentContainer.saveContext()
      
    default:
      break
    }
  }
}

