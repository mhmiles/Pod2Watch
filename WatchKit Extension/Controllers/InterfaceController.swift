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
  
  lazy var resultsController: NSFetchedResultsController<Episode> = {
    let context = PersistentContainer.shared.viewContext
    
    let request: NSFetchRequest<Episode> = Episode.fetchRequest()
    request.sortDescriptors = [NSSortDescriptor(key: "sortIndex", ascending: true)]
    
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
    
    _ = PodcastTransferManager.shared
    
    setUpRows()
  }
  
  override func willActivate() {
    super.willActivate()
    
    PodcastTransferManager.shared.requestPending()
  }
  
  fileprivate func setUpRows() {
    let rowCount = resultsController.fetchedObjects?.count ?? 0
    
    if rowCount > 0 {
      podcastsTable.setNumberOfRows(rowCount, withRowType: "Podcast")
      
      for index in 0..<rowCount {
        let rowController = podcastsTable.rowController(at: index) as! PodcastsTableRowController
        
        let episode = resultsController.object(at: IndexPath(row: index, section: 0))
        
        rowController.artworkImage.setImage(episode.artworkImage)
        rowController.podcastTitleLabel.setText(episode.podcast.title)
        rowController.epiosodeTitleLabel.setText(episode.title)
        
        rowController.progressBarWidth = contentFrame.width-12.0
        rowController.setProgressBarCompletion(episode.startTime/max(1, episode.playbackDuration))
      }
    } else {
      podcastsTable.setNumberOfRows(1, withRowType: "NoPodcasts")
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
    guard let episodes = resultsController.fetchedObjects else {
      return
    }
    
    let episodeQueue = [episodes[rowIndex]] + episodes.enumerated().filter({ (index, episode) -> Bool in
      return index > rowIndex && episode.isPlayed
    }).map { $1 }
    
    AudioPlayer.shared.queueEpisodes(episodeQueue)
    
    pushController(withName: "NowPlaying", context: nil)
  }
  
  @IBAction func handleDeleteAll() {
    WKInterfaceDevice.current().play(.success)
    
    AudioPlayer.shared.pause()
    PodcastTransferManager.shared.deleteAllPodcasts()
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

extension InterfaceController: NSFetchedResultsControllerDelegate {
  func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                  didChange anObject: Any,
                  at indexPath: IndexPath?,
                  for type: NSFetchedResultsChangeType,
                  newIndexPath: IndexPath?) {
    guard let episode = anObject as? Episode else {
      return
    }
    
    switch type {
    case .insert:
      if controller.fetchedObjects?.count ?? 0 > 1 {
        let rows = IndexSet(integer: newIndexPath!.row)
        podcastsTable.insertRows(at: rows, withRowType: "Podcast")
        
        let rowController = podcastsTable.rowController(at: newIndexPath!.row) as! PodcastsTableRowController
        
        rowController.artworkImage.setImage(episode.artworkImage)
        rowController.podcastTitleLabel.setText(episode.podcast.title)
        rowController.epiosodeTitleLabel.setText(episode.title)
        
        rowController.progressBarWidth = contentFrame.width-12.0
        rowController.setProgressBarCompletion(episode.startTime/max(1, episode.playbackDuration))
      } else {
        setUpRows()
      }
      
    case .update:
      guard let rowController = podcastsTable.rowController(at: newIndexPath!.row) as? PodcastsTableRowController else {
        return
      }

      rowController.setProgressBarCompletion(episode.startTime/max(1, episode.playbackDuration))
    
    case .delete:
      if controller.fetchedObjects?.count ?? 0 > 0 {
        let rows = IndexSet(integer: indexPath!.row)
        podcastsTable.removeRows(at: rows)
      } else {
        setUpRows()
      }
      
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
