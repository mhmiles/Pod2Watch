//
//  InterfaceController.swift
//  Pod2Watch WatchKit Extension
//
//  Created by Miles Hollingsworth on 2/8/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import WatchKit
import Foundation
import WatchConnectivity
import CoreData

class InterfaceController: WKInterfaceController, URLSessionDelegate {
  @IBOutlet var podcastsTable: WKInterfaceTable!
  
  var session: WCSession! {
    didSet {
      session.delegate = self
      session.activate()
    }
  }
  
  lazy var resultsController: NSFetchedResultsController<PodcastEpisode> = {
    let context = PersistentContainer.shared.viewContext
    
    let request: NSFetchRequest<PodcastEpisode> = PodcastEpisode.fetchRequest()
    request.sortDescriptors = [NSSortDescriptor(key: "podcastTitle", ascending: true)]
    
    let controller = NSFetchedResultsController(fetchRequest: request,
                                                managedObjectContext: context,
                                                sectionNameKeyPath: nil,
                                                cacheName: nil)
    
    controller.delegate = self
    try! controller.performFetch()
    
    return controller
  }()
  
  override func awake(withContext context: Any?) {
    super.awake(withContext: context)
    
    session = WCSession.default()
    
    let rowCount = resultsController.fetchedObjects?.count ?? 0
    podcastsTable.setNumberOfRows(rowCount, withRowType: "Podcast")
    
    for index in 0..<rowCount {
      let rowController = podcastsTable.rowController(at: index) as! PodcastsTableRowController
      
      let episode = resultsController.object(at: IndexPath(row: index, section: 0))
      rowController.podcastTitleLabel.setText(episode.podcastTitle)
      rowController.epiosodeTitleLabel.setText(episode.episodeTitle)
      
      rowController.progressBarWidth = contentFrame.width-12.0
      rowController.setProgressBarCompletion(episode.startTime/max(1, episode.playbackDuration))
    }
  }
  
  override func willActivate() {
    super.willActivate()
    
    if session.activationState == .activated {
      requestDeletes()
    }
  }
  
  override func didDeactivate() {
    // This method is called when watch view controller is no longer visible
    super.didDeactivate()
  }
  
  func setStartTime(atIndex index: Int) {
    pushController(withName: "StartTime", context: nil)
  }
  
  override func willDisappear() {
    super.willDisappear()
    
    
  }
  
  override func table(_ table: WKInterfaceTable, didSelectRowAt rowIndex: Int) {
    pushController(withName: "Details", context: resultsController.object(at: IndexPath(row: rowIndex, section: 0)))
  }
}

extension InterfaceController: URLSessionDownloadDelegate {
  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    print("DONE: \(location)")
  }
  
  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
    print(Float(bytesWritten)/Float(totalBytesExpectedToWrite))
  }
}

extension InterfaceController: WCSessionDelegate {
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
  
  private func deletePodcasts(ids podcastIDs: [NSNumber]) {
    let request: NSFetchRequest<PodcastEpisode> = PodcastEpisode.fetchRequest()
    request.predicate = NSPredicate(format: "podcastID IN %@", podcastIDs)
    
    let context = PersistentContainer.shared.viewContext
    let episodesToDelete = try! context.fetch(request)
    let deletedPodcastIDs = episodesToDelete.map { NSNumber(value: $0.podcastID) }
    
    for episode in episodesToDelete {
      if let fileURLString = episode.fileURLString,
        let fileURL = URL(string: fileURLString) {
        try? FileManager.default.removeItem(at: fileURL)
      } else {
        
      }
      
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
      let fetchRequest: NSFetchRequest<NSFetchRequestResult> = PodcastEpisode.fetchRequest()
      let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
      try! PersistentContainer.shared.viewContext.execute(deleteRequest)
      PersistentContainer.saveContext()
      
      replyHandler(["type": MessageType.confirmDeleteAll])
      
    default:
      break
    }
  }
  
  func session(_ session: WCSession, didReceive file: WCSessionFile) {
    let fileManager = FileManager.default
    fileManager.delegate = self
    
    let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.com.hollingsware.pod2watch")!
    
    let saveURL: URL
    if file.fileURL.pathExtension != "mov" {
      saveURL = containerURL.appendingPathComponent(file.fileURL.lastPathComponent).deletingPathExtension()
    } else {
      saveURL = containerURL.appendingPathComponent(file.fileURL.lastPathComponent)
    }
    
    print("SAVING: \(saveURL)")
    
    do {
      try fileManager.moveItem(at: file.fileURL, to: saveURL)
    } catch let error {
      print(error)
    }
    
    guard let metadata = file.metadata, let podcastID = metadata["podcastID"] as? Int64 else {
      print("NO METADATA")
      return
    }
    
    let context = PersistentContainer.shared.viewContext
    let entity = NSEntityDescription.entity(forEntityName: "PodcastEpisode", in: context)!
    let episode = PodcastEpisode(entity: entity, insertInto: context)
    
    episode.podcastID = podcastID
    episode.podcastTitle = metadata["podcastTitle"] as? String
    episode.episodeTitle = metadata["episodeTitle"] as? String
    episode.playbackDuration = metadata["playbackDuration"] as? Double ?? 0
    episode.fileURLString = saveURL.absoluteString
    
    PersistentContainer.saveContext()
    
    //    presentMediaPlayerController(with: saveURL, options: nil) { (success, duration, error) in
    //      print(error)
    //    }
  }
}

extension InterfaceController: FileManagerDelegate {
  func fileManager(_ fileManager: FileManager, shouldMoveItemAt srcURL: URL, to dstURL: URL) -> Bool {
    return true
  }
}

extension InterfaceController: NSFetchedResultsControllerDelegate {
  func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                  didChange anObject: Any,
                  at indexPath: IndexPath?,
                  for type: NSFetchedResultsChangeType,
                  newIndexPath: IndexPath?) {
    guard let episode = anObject as? PodcastEpisode else {
      return
    }
    
    switch type {
    case .insert:
      let rows = IndexSet(integer: newIndexPath!.row)
      podcastsTable.insertRows(at: rows, withRowType: "Podcast")
      
      let rowController = podcastsTable.rowController(at: newIndexPath!.row) as! PodcastsTableRowController
      rowController.podcastTitleLabel.setText(episode.podcastTitle)
      rowController.epiosodeTitleLabel.setText(episode.episodeTitle)
      
      rowController.progressBarWidth = contentFrame.width-12.0
      rowController.setProgressBarCompletion(episode.startTime/max(1, episode.playbackDuration))
      
    case .update:
      guard let rowController = podcastsTable.rowController(at: newIndexPath!.row) as? PodcastsTableRowController else {
        return
      }
      
      rowController.setProgressBarCompletion(episode.startTime/max(1, episode.playbackDuration))
    
    case .delete:
      let rows = IndexSet(integer: indexPath!.row)
      podcastsTable.removeRows(at: rows)
      
    default:
      break
    }
  }
  
  func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                  didChange sectionInfo: NSFetchedResultsSectionInfo,
                  atSectionIndex sectionIndex: Int,
                  for type: NSFetchedResultsChangeType) {
    
  }
}
