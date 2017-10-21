//
//  RecentPodcastsViewController.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 2/23/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import UIKit
import MediaPlayer
import CoreData
import ReactiveSwift
import racAdditions

class RecentPodcastsViewController: UITableViewController {
  fileprivate lazy var libraryResultsController: NSFetchedResultsController<LibraryEpisode> = {
    let request: NSFetchRequest<LibraryEpisode> = LibraryEpisode.fetchRequest()
    request.sortDescriptors = [NSSortDescriptor(key: #keyPath(LibraryEpisode.releaseDate),
                                                ascending: false)]

    let controller = NSFetchedResultsController(fetchRequest: request,
                                                managedObjectContext: InMemoryContainer.shared.viewContext,
                                                sectionNameKeyPath: #keyPath(LibraryEpisode.releaseDateLabel),
                                                cacheName: nil)

    try! controller.performFetch()
    controller.delegate = self

    return controller
  }()
  
  private func episode(at indexPath: IndexPath) -> LibraryEpisode {
    return libraryResultsController.object(at: indexPath)
  }

  fileprivate lazy var syncResultsController: NSFetchedResultsController<TransferredEpisode> = {
    let request: NSFetchRequest<TransferredEpisode> = TransferredEpisode.fetchRequest()
    request.sortDescriptors = [NSSortDescriptor(key: #keyPath(LibraryEpisode.releaseDate),
                                                ascending: false)]

    let controller = NSFetchedResultsController<TransferredEpisode>(fetchRequest: request,
                                                                managedObjectContext: PersistentContainer.shared.viewContext,
                                                                sectionNameKeyPath: nil,
                                                                cacheName: nil)

    try! controller.performFetch()
    controller.delegate = self

    return controller
  }()

  override func viewDidLoad() {
    super.viewDidLoad()

    _ = syncResultsController

    NotificationCenter.default.addObserver(forName: .podcastLibraryDidReload,
                                           object: InMemoryContainer.shared,
                                           queue: OperationQueue.main) { [weak self] _ in
                                            try! self?.libraryResultsController.performFetch()
                                            self?.tableView.reloadData()
    }
    
    navigationController?.navigationBar.prefersLargeTitles = true
    
    tableView.sectionFooterHeight = 0
  }
  
  @IBAction func openPodcasts() {
    UIApplication.shared.openPodcasts()
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  // MARK: - Table view data source

  override func numberOfSections(in tableView: UITableView) -> Int {
    return libraryResultsController.sections?.count ?? 0
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return libraryResultsController.sections?[section].numberOfObjects ?? 0
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard let cell = tableView.dequeueReusableCell(withIdentifier: "RecentEpisodeCell", for: indexPath) as? RecentEpisodeCell else {
      abort()
    }

    let episode = self.episode(at: indexPath)
    cell.viewModel = episode.recentEpisodeCellViewModel


    return cell
  }

  override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    guard let header = Bundle.main.loadNibNamed("RecentPodcastsHeaderView", owner: nil, options: nil)?.first as? RecentPodcastsHeaderView else {
      return nil
    }

    header.label.text = libraryResultsController.sections?[section].name

    return header
  }

  override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    return 40.0
  }
  
  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    guard let cell = tableView.cellForRow(at: indexPath) as? RecentEpisodeCell,
      let syncState = cell.syncButton.syncState else {
        return false
    }
    
    return syncState != .noSync
  }
  
  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      let libraryEpisode = episode(at: indexPath)
      
      guard let episode = TransferredEpisode.existing(persistentID: libraryEpisode.persistentID) else {
        return
      }
      
      PodcastTransferManager.shared.delete(episode)
    }
  }
  
  override func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
    guard let cell = tableView.cellForRow(at: indexPath) as? RecentEpisodeCell,
      let syncState = cell.syncButton.syncState else {
        return "Delete"
    }
    
    return syncState == .synced ? "Delete" : "Cancel"
  }
}

// MARK: - NSFetchedResultsControllerDelegate

extension RecentPodcastsViewController: NSFetchedResultsControllerDelegate {
  func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    tableView.beginUpdates()
  }

  func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                  didChange anObject: Any,
                  at indexPath: IndexPath?,
                  for type: NSFetchedResultsChangeType,
                  newIndexPath: IndexPath?) {
    if controller == syncResultsController,
      let episode = anObject as? TransferredEpisode,
      let existing = LibraryEpisode.existing(persistentID: episode.persistentID),
      let existingIndexPath = libraryResultsController.indexPath(forObject: existing) {
      switch type {
      case .insert:
        fallthrough
      case .update:
        fallthrough
      case .delete:
        tableView.reloadRows(at: [existingIndexPath], with: .fade)

      default:
        break
      }
    }
  }

  func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    tableView.endUpdates()
  }
}
