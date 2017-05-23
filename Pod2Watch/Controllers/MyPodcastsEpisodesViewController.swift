//
//  MyPodcastsEpisodesViewController.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 2/10/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import UIKit
import CoreData

class MyPodcastsEpisodesViewController: UITableViewController {
  var podcastTitle: String! {
    didSet {
      navigationItem.title = podcastTitle
    }
  }

  @IBOutlet weak var autoTransferSwitch: UISwitch!

  fileprivate lazy var libraryResultsController: NSFetchedResultsController<LibraryEpisode> = {
    let request: NSFetchRequest<LibraryEpisode> = LibraryEpisode.fetchRequest()
    request.predicate = NSPredicate(format: "podcast.title == %@", self.podcastTitle)
    request.sortDescriptors = [NSSortDescriptor(key: #keyPath(LibraryEpisode.releaseDate),
                                                ascending: false)]
    
    let context = InMemoryContainer.shared.viewContext
    let controller = NSFetchedResultsController<LibraryEpisode>(fetchRequest: request,
                                                                managedObjectContext: context,
                                                                sectionNameKeyPath: nil,
                                                                cacheName: nil)
    
    try! controller.performFetch()
    controller.delegate = self

    return controller
  }()

  fileprivate lazy var syncResultsController: NSFetchedResultsController<TransferredEpisode> = {
    let request: NSFetchRequest<TransferredEpisode> = TransferredEpisode.fetchRequest()
    request.predicate = NSPredicate(format: "podcast.title == %@", self.podcastTitle)
    request.sortDescriptors = [NSSortDescriptor(key: #keyPath(TransferredEpisode.releaseDate),
                                                ascending: false)]
    
    let context = PersistentContainer.shared.viewContext
    let controller = NSFetchedResultsController<TransferredEpisode>(fetchRequest: request,
                                                                    managedObjectContext: context,
                                                                    sectionNameKeyPath: nil,
                                                                    cacheName: nil)
    
    try! controller.performFetch()
    controller.delegate = self

    return controller
  }()

  var isAutoTransferActive = false

  override func viewDidLoad() {
    super.viewDidLoad()
    
    if let transferredPodcast = TransferredPodcast.existing(title: podcastTitle) {
      isAutoTransferActive = transferredPodcast.isAutoTransferred
      autoTransferSwitch.isOn = transferredPodcast.isAutoTransferred
    }

    NotificationCenter.default.addObserver(forName: InMemoryContainer.PodcastLibraryDidReload,
                                           object: InMemoryContainer.shared,
                                           queue: OperationQueue.main) { [weak self] _ in
                                            try! self?.libraryResultsController.performFetch()
                                            self?.tableView.reloadData()
    }

    _ = syncResultsController
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
    let cell = tableView.dequeueReusableCell(withIdentifier: "EpisodeCell", for: indexPath) as! MyPodcastsEpisodeCell

    let rowEpisode = libraryResultsController.object(at: indexPath)
    cell.titleLabel.text = rowEpisode.title
    cell.durationLabel.text = rowEpisode.secondaryLabelText

    if let synced = TransferredEpisode.existing(persistentID: rowEpisode.persistentID) {
      if synced.shouldDelete {
        cell.syncButton.syncState = .pending
      } else if synced.isTransferred {
        cell.syncButton.syncState = .synced
      } else if synced.hasBegunTransfer {
        cell.syncButton.syncState = .syncing
      } else {
        cell.syncButton.syncState = .pending
      }
    } else {
      cell.syncButton.syncState = .noSync
      
      cell.syncHandler = { [weak cell] in
        cell?.syncHandler = nil
        PodcastTransferManager.shared.transfer(rowEpisode)
      }
    }
    
    return cell
  }
  
  @IBAction func handleAutoTransferSwitchChange(_ sender: UISwitch) {
    guard let libraryPodcast = LibraryPodcast.existing(title: podcastTitle) else {
      return
    }
    
    let transferredPodcast = TransferredPodcast.existing(title: podcastTitle) ?? TransferredPodcast(libraryPodcast)
    transferredPodcast.isAutoTransferred = sender.isOn
    
    PersistentContainer.saveContext()
    
    isAutoTransferActive = sender.isOn
    tableView.reloadSections([0], with: .fade)
    
    if isAutoTransferActive {
      _ = PodcastTransferManager.shared.handleAutoTransfer(podcast: transferredPodcast)
    }
  }
}

//MARK: - NSFetchedResultsControllerDelegate

extension MyPodcastsEpisodesViewController: NSFetchedResultsControllerDelegate {
  func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    tableView.beginUpdates()
  }
  
  func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
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
    } else if controller == libraryResultsController {
      switch type {
      case .insert:
        tableView.insertRows(at: [newIndexPath!], with: .automatic)
        
      case .delete:
        tableView.deleteRows(at: [indexPath!], with: .automatic)
        
      case .update:
        tableView.reloadRows(at: [indexPath!], with: .fade)
        
      case .move:
        tableView.moveRow(at: indexPath!, to: newIndexPath!)
      }
    }
  }
  
  func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    tableView.endUpdates()
  }
}

