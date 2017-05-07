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
  var podcast: LibraryPodcast! {
    didSet {
      navigationItem.title = podcast.title
    }
  }
  
  @IBOutlet weak var autoTransferSwitch: UISwitch!
  
  fileprivate lazy var libraryResultsController: NSFetchedResultsController<LibraryEpisode> = {
    let request: NSFetchRequest<LibraryEpisode> = LibraryEpisode.fetchRequest()
    request.sortDescriptors = [NSSortDescriptor(key: "releaseDate", ascending: false)]
    request.predicate = NSPredicate(format: "podcast == %@", self.podcast)
    
    let controller = NSFetchedResultsController<LibraryEpisode>(fetchRequest: request,
                                                                       managedObjectContext: InMemoryContainer.shared.viewContext,
                                                                       sectionNameKeyPath: nil,
                                                                       cacheName: nil)
    
    try! controller.performFetch()
    controller.delegate = self
    
    return controller
  }()
  
  fileprivate lazy var syncResultsController: NSFetchedResultsController<TransferredEpisode> = {
    let request: NSFetchRequest<TransferredEpisode> = TransferredEpisode.fetchRequest()
    request.predicate = NSPredicate(format: "podcastTitle == %@", self.podcast.title ?? "")
    request.sortDescriptors = [NSSortDescriptor(key: "releaseDate", ascending: false)]
    
    let controller = NSFetchedResultsController<TransferredEpisode>(fetchRequest: request,
                                                                managedObjectContext: PersistentContainer.shared.viewContext,
                                                                sectionNameKeyPath: nil,
                                                                cacheName: nil)
    
    try! controller.performFetch()
    controller.delegate = self
    
    return controller
  }()

  var isAutoTransferActive = false
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let request: NSFetchRequest<TransferredPodcast> = TransferredPodcast.fetchRequest()
    request.predicate = NSPredicate(format: "title == %@", podcast.title!)
    let context = PersistentContainer.shared.viewContext
    
    if let transferredPodcast = try! context.fetch(request).first {
      isAutoTransferActive = transferredPodcast.isAutoTransferred
      autoTransferSwitch.isOn = transferredPodcast.isAutoTransferred
    }
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
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
    
    if let synced = syncResultsController.fetchedObjects?.first(where: { $0.persistentID == rowEpisode.persistentID }) {
      if synced.shouldDelete {
        cell.syncButton.syncState = .pending
      } else if synced.hasBegunTransfer == false {
        cell.syncButton.syncState = .preparing
      } else if synced.isTransferred {
        cell.syncButton.syncState = .synced
      } else {
        cell.syncButton.syncState = .syncing
      }
    } else {
      cell.syncButton.syncState = .noSync
      
      cell.syncHandler = { [weak cell] in
        cell?.syncHandler = nil
        PodcastTransferManager.shared.transfer(rowEpisode)
      }
    }
    
    if isAutoTransferActive {
      cell.syncButton.isEnabled = false
    }
    
    return cell
  }
  
  @IBAction func handleAutoTransferSwitchChange(_ sender: UISwitch) {
    let request: NSFetchRequest<TransferredPodcast> = TransferredPodcast.fetchRequest()
    request.predicate = NSPredicate(format: "title == %@", podcast.title!)
    let context = PersistentContainer.shared.viewContext
    
    let transferredPodcast = try! context.fetch(request).first ?? TransferredPodcast(podcast, context: context)
    transferredPodcast.isAutoTransferred = sender.isOn
    
    PersistentContainer.saveContext()

    isAutoTransferActive = sender.isOn
    tableView.reloadSections([0], with: .fade)
  }
}

extension MyPodcastsEpisodesViewController: NSFetchedResultsControllerDelegate {
  func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    tableView.beginUpdates()
  }
  
  func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
    if controller == syncResultsController,
      let episode = anObject as? TransferredEpisode,
      let existing = libraryResultsController.fetchedObjects?.first(where: { $0.persistentID == episode.persistentID }),
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
      print(anObject)
    }
  }
  
  func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    tableView.endUpdates()
  }
}

