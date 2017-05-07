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
    deletePodcasts(ids: [NSNumber(value: episode.persistentID)])
  }
  
  func deleteAllPodcasts() {
    let context = PersistentContainer.shared.viewContext
    let request: NSFetchRequest<Episode> = Episode.fetchRequest()
    guard let episodes = try? context.fetch(request) else {
      return
    }
    
    context.perform {
      for episode in episodes {
        context.delete(episode)
      }
    }
    
    PersistentContainer.saveContext()
    
    let fileManager = FileManager.default
    try? fileManager.contentsOfDirectory(at: saveDirectoryURL,
                                    includingPropertiesForKeys: nil).forEach { try? fileManager.removeItem(at: $0) }
    
    session.sendMessage(["type": MessageType.confirmDeleteAll], replyHandler: nil)
  }
}

extension PodcastTransferManager: WCSessionDelegate {
  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    switch activationState {
    case .activated:
      requestDeletes()
      
    default:
      break
    }
  }
  
  fileprivate func requestDeletes() {
    let message = ["type": MessageType.requestDeletes]
    
    session.sendMessage(message,
                        replyHandler: { [unowned self] (deletes) in
                          guard let podcastIDsToDelete = deletes["payload"] as? [NSNumber] else {
                            return
                          }
                          
                          self.deletePodcasts(ids: podcastIDsToDelete)
    }) { (error) in
      print(error)
    }
  }
  
  fileprivate func deletePodcasts(ids podcastIDs: [NSNumber]) {
    let request: NSFetchRequest<Episode> = Episode.fetchRequest()
    request.predicate = NSPredicate(format: "podcastID IN %@", podcastIDs)
    
    let context = PersistentContainer.shared.viewContext
    let episodesToDelete = try! context.fetch(request)
    let deletedPodcastIDs = episodesToDelete.map { NSNumber(value: $0.persistentID) }
    
    for episode in episodesToDelete {
      try? FileManager.default.removeItem(at: episode.fileURL)
      
      context.delete(episode)
    }
    
    PersistentContainer.saveContext()
    
    let message: [String: Any] = [
      "type": MessageType.confirmDeletes,
      "payload": deletedPodcastIDs
    ]
    
    session.sendMessage(message, replyHandler: nil) { (error) in
      print(error)
    }
  }
  
  func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
    guard let messageType = message["type"] as? String else {
      return
    }
    
    switch messageType {
    case MessageType.sendDeletes:
      guard let podcastIDsToDelete = message["payload"] as? [NSNumber] else {
        return
      }
      
      deletePodcasts(ids: podcastIDsToDelete)
      
    default:
      break
    }
  }
  
  func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
    guard let messageType = message["type"] as? String else {
      return
    }
    
    switch messageType {
    case MessageType.sendDeleteAll:
      deleteAllPodcasts()
      
    default:
      break
    }
  }
  
  func session(_ session: WCSession, didReceive file: WCSessionFile) {
    let fileManager = FileManager.default
    fileManager.delegate = self
   
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
    
    print(fileManager.fileExists(atPath: saveURL.absoluteString))
    
    guard let metadata = file.metadata, let persistentID = metadata["persistentID"] as? Int64 else {
      print("NO METADATA")
      return
    }
    
    let context = PersistentContainer.shared.viewContext
    let entity = NSEntityDescription.entity(forEntityName: "Episode", in: context)!
    let episode = Episode(entity: entity, insertInto: context)
    
    episode.persistentID = persistentID
    episode.title = metadata["episodeTitle"] as? String
    episode.playbackDuration = metadata["playbackDuration"] as? Double ?? 0
    episode.fileURL = saveURL
    
    let podcastTitle = metadata["podcastTitle"] as! String
    let request: NSFetchRequest<Podcast> = Podcast.fetchRequest()
    request.predicate = NSPredicate(format: "title == %@", podcastTitle)
    
    episode.podcast = (try? context.fetch(request))?.first ?? Podcast(title: podcastTitle, context: context)
    episode.podcast.addToEpisodes(episode)
    
    if let artworkImageData = metadata["artworkImage"] as? Data,
      let artworkImage = UIImage(data: artworkImageData) {
      episode.podcast.artworkImage = artworkImage
    }
    
    PersistentContainer.saveContext()
  }
  
  func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
    
  }
}

extension PodcastTransferManager: FileManagerDelegate {
}
