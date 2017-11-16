//
//  EpisodeListController.swift
//  Pod2Watch WatchKit Extension
//
//  Created by Miles Hollingsworth on 2/8/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import WatchKit
import Foundation
import WatchConnectivity
import CoreData
import ReactiveSwift
import AVFoundation
import UserNotifications

class EpisodeListController: WKInterfaceController, URLSessionDelegate {
  @IBOutlet var podcastsTable: WKInterfaceTable!
  
  lazy var resultsController: NSFetchedResultsController<Episode> = {
    let context = PersistentContainer.shared.viewContext
    
    let request: NSFetchRequest<Episode> = Episode.fetchRequest()
    request.sortDescriptors = [NSSortDescriptor(key: #keyPath(Episode.sortIndex),
                                                ascending: true)]
    
    let controller = NSFetchedResultsController(fetchRequest: request,
                                                managedObjectContext: context,
                                                sectionNameKeyPath: nil,
                                                cacheName: nil)
    
    controller.delegate = self
    try! controller.performFetch()
    
    return controller
  }()
  
  let player = AudioPlayer.shared
  
  override func awake(withContext context: Any?) {
    super.awake(withContext: context)
    
    _ = PodcastTransferManager.shared
    
    setUpRows()
    
    NotificationCenter.default.addObserver(forName: .podcastSecurityFailed,
                                           object: nil,
                                           queue: OperationQueue.main) { notification in
                                            self.presentController(withName: "PodcastSecurityError",
                                                                   context: notification.userInfo)
    }
    
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(EpisodeListController.handleDownloadDidBegin),
                                           name: .podcastDownloadDidBegin,
                                           object: nil)
  }
  
  private let nowPlayingDisposable = SerialDisposable()
  
  override func willActivate() {
    nowPlayingDisposable.inner = player.currentItem.producer.startWithValues { [weak self] currentItem in
      guard let episodes = self?.resultsController.fetchedObjects else {
        return
      }
      
      for (index, episode) in episodes.enumerated() {
        if let rowController = self?.podcastsTable.rowController(at: index) as? EpisodesTableRowController {
          guard let currentItem = currentItem,
            let fileURL = episode.fileURL else {
              rowController.isSelected = false
              continue
          }
          
          rowController.isSelected = fileURL == currentItem.asset.url
        }
      }
    }
    
    
  }
  
  override func willDisappear() {
    nowPlayingDisposable.inner = nil
  }
  
  fileprivate func setUpRows() {
    guard let episodes = resultsController.fetchedObjects, episodes.count > 0 else {
      podcastsTable.setNumberOfRows(1, withRowType: "NoPodcasts")
      return
    }
    
    podcastsTable.setNumberOfRows(episodes.count, withRowType: "Podcast")
    
    for (index, episode) in episodes.enumerated() {
      let rowController = podcastsTable.rowController(at: index) as! EpisodesTableRowController
      
      rowController.configure(withEpisode: episode, barWidth: contentFrame.width-12.0)
    }
  }
  
  private let playDisposable = SerialDisposable()
  
  override func table(_ table: WKInterfaceTable, didSelectRowAt rowIndex: Int) {
    guard let episodes = resultsController.fetchedObjects else {
      return
    }
    
    guard let _ = episodes[rowIndex].fileURL else {
      presentController(withName: "NotSynced", context: nil)
      return
    }
    
    if let currentItem = player.currentItem.value,
      currentItem.asset.url == episodes[rowIndex].fileURL {
      WKInterfaceDevice.current().play(.click)
    } else {
      player.episodeQueue = Array(episodes[rowIndex...]).filter({ $0.fileURL != nil })
      playDisposable.inner = player.currentItem.producer.skipNil().take(first: 1).startWithCompleted {
        try? AudioPlayer.shared.play()
      }
      
      WKInterfaceDevice.current().play(.success)
    }
    
    pushController(withName: "NowPlaying", context: nil)
  }
  
  override func contextForSegue(withIdentifier segueIdentifier: String) -> Any? {
    return nil
  }
  
  @IBAction func handleDeleteAll() {
    WKInterfaceDevice.current().play(.click)
    
    presentController(withName: "DeleteAll", context: nil)
  }
  
  @IBAction func handleDownload() {
    pushController(withName: "DownloadPodcast", context: nil)
  }
  
  @objc func handleDownloadDidBegin() {
    let center = UNUserNotificationCenter.current()
    center.getNotificationSettings(completionHandler: { (settings) in
      switch settings.authorizationStatus {
      case .notDetermined:
        self.presentController(withName: "RequestAuthorization",
                          context: nil)
        
      default:
        break
      }
    })
  }
}

// MARK: - NSFetchedResultsControllerDelegate

extension EpisodeListController: NSFetchedResultsControllerDelegate {
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
      if controller.fetchedObjects?.count ?? 0 == 1 {
        setUpRows()
        break
      } else {
        podcastsTable.insertRows(at: IndexSet(integer: newIndexPath!.row),
                                 withRowType: "Podcast")
      }
      
      fallthrough
      
    case .update:
      guard let rowController = podcastsTable.rowController(at: newIndexPath!.row) as? EpisodesTableRowController else {
        return
      }
      
      rowController.configure(withEpisode: episode, barWidth: contentFrame.width-12.0)
      
    case .delete:
      if controller.fetchedObjects?.count ?? 0 == 0 {
        setUpRows()
      } else {
        podcastsTable.removeRows(at: IndexSet(integer: indexPath!.row))
      }
      
    default:
      break
    }
  }
}
