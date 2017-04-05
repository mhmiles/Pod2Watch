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
  
  fileprivate lazy var libraryResultsController: NSFetchedResultsController<LibraryPodcastEpisode> = {
    let request: NSFetchRequest<LibraryPodcastEpisode> = LibraryPodcastEpisode.fetchRequest()
    request.sortDescriptors = [NSSortDescriptor(key: "releaseDate", ascending: false)]
    request.predicate = NSPredicate(format: "podcastTitle == %@", self.podcastTitle)
    
    let controller = NSFetchedResultsController<LibraryPodcastEpisode>(fetchRequest: request,
                                                                managedObjectContext: InMemoryContainer.shared.viewContext,
                                                                sectionNameKeyPath: nil,
                                                                cacheName: nil)
    
    try! controller.performFetch()
    controller.delegate = self

    return controller
  }()
  
  fileprivate lazy var syncResultsController: NSFetchedResultsController<PodcastEpisode> = {
    let request: NSFetchRequest<PodcastEpisode> = PodcastEpisode.fetchRequest()
    request.sortDescriptors = [NSSortDescriptor(key: "releaseDate", ascending: false)]
    request.predicate = NSPredicate(format: "podcastTitle == %@", self.podcastTitle)
    
    let controller = NSFetchedResultsController<PodcastEpisode>(fetchRequest: request,
                                                                managedObjectContext: PersistentContainer.shared.viewContext,
                                                                sectionNameKeyPath: nil,
                                                                cacheName: nil)

    controller.delegate = self
    
    return controller
  }()
  
//  var session: WCSession! {
//    didSet {
//      session.delegate = self
//      session.activate()
//    }
//  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    try! syncResultsController.performFetch()
    
    // Uncomment the following line to preserve selection between presentations
    // self.clearsSelectionOnViewWillAppear = false
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem()
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
    cell.titleLabel.text = rowEpisode.episodeTitle
    cell.durationLabel.text = rowEpisode.secondaryLabelText
    
    if let synced = syncResultsController.fetchedObjects?.first(where: { $0.podcastID == rowEpisode.podcastID }) {
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
      
      cell.syncHandler = {
        PodcastTransferManager.shared.transfer(rowEpisode)
      }
    }
    
    return cell
  }
}

extension MyPodcastsEpisodesViewController: NSFetchedResultsControllerDelegate {
  func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
    if controller == syncResultsController,
      let episode = anObject as? PodcastEpisode,
      let existing = libraryResultsController.fetchedObjects?.first(where: { $0.podcastID == episode.podcastID }),
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
}

