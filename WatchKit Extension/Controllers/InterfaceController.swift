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

  override func awake(withContext context: Any?) {
    super.awake(withContext: context)

    _ = PodcastTransferManager.shared

    setUpRows()

    AudioPlayer.shared.currentEpisode.producer.combinePrevious(nil).startWithValues { [weak self] previous, current in
      guard let episodes = self?.resultsController.fetchedObjects else {
        return
      }

      if let previous = previous, let index = episodes.index(of: previous),
        let rowController = self?.podcastsTable.rowController(at: index) as? PodcastsTableRowController {
        rowController.isSelected = false
      }

      if let current = current, let index = episodes.index(of: current),
        let rowController = self?.podcastsTable.rowController(at: index) as? PodcastsTableRowController {
        rowController.isSelected = true
      }
    }
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

        rowController.podcastTitleLabel.setText(episode.podcast.title)
        rowController.epiosodeTitleLabel.setText(episode.title)

        rowController.progressBarWidth = contentFrame.width-12.0
        rowController.setProgressBarCompletion(episode.startTime/max(1, episode.playbackDuration))

        rowController.artworkImageDisposable = episode.artworkImage.producer.startWithValues(rowController.artworkImage.setImage)
      }
    } else {
      podcastsTable.setNumberOfRows(1, withRowType: "NoPodcasts")
    }
  }

  func setStartTime(atIndex index: Int) {
    pushController(withName: "StartTime", context: nil)
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

// MARK: - NSFetchedResultsControllerDelegate

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

        rowController.podcastTitleLabel.setText(episode.podcast.title)
        rowController.epiosodeTitleLabel.setText(episode.title)

        rowController.artworkImageDisposable = episode.artworkImage.producer.startWithValues(rowController.artworkImage.setImage)

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

      rowController.artworkImage.setImage(episode.artworkImage.value)

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
}
