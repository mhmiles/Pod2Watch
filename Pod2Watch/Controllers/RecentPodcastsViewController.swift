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
  
  @IBOutlet weak var segmentedTitle: UISegmentedControl!

  fileprivate lazy var libraryResultsController: NSFetchedResultsController<LibraryEpisode> = {
    let request: NSFetchRequest<LibraryEpisode> = LibraryEpisode.fetchRequest()
    request.sortDescriptors = [NSSortDescriptor(key: "releaseDate", ascending: false)]
    
    let controller = NSFetchedResultsController(fetchRequest: request,
                                                managedObjectContext: InMemoryContainer.shared.viewContext,
                                                sectionNameKeyPath: "releaseDateLabel",
                                                cacheName: nil)
    
    try! controller.performFetch()
    controller.delegate = self
    
    return controller
  }()
  
  fileprivate lazy var syncResultsController: NSFetchedResultsController<TransferredEpisode> = {
    let request: NSFetchRequest<TransferredEpisode> = TransferredEpisode.fetchRequest()
    request.sortDescriptors = [NSSortDescriptor(key: "releaseDate", ascending: false)]
    
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
    
    segmentedTitle.setTitleTextAttributes([NSFontAttributeName: UIFont.systemFont(ofSize: 16)],
                                          for: .normal)
    
    _ = syncResultsController
    
    NotificationCenter.default.addObserver(forName: InMemoryContainer.PodcastLibraryDidReload,
                                           object: InMemoryContainer.shared,
                                           queue: OperationQueue.main) { [weak self] _ in
                                            try! self?.libraryResultsController.performFetch()
                                            self?.tableView.reloadData()
    }
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
    let cell = tableView.dequeueReusableCell(withIdentifier: "RecentEpisodeCell", for: indexPath) as! RecentEpisodeCell
    
    let episode = libraryResultsController.object(at: indexPath)
    
    cell.artworkView.rac_image <~ episode.podcastArtworkProducer
    
    cell.titleLabel.text = episode.title
    cell.durationLabel.text = episode.recentSecondaryLabelText
    
    if let synced = TransferredEpisode.existing(persistentID: episode.persistentID) {
      if synced.shouldDelete {
        cell.syncButton.syncState = .pending
      } else if synced.isTransferred {
        cell.syncButton.syncState = .synced
      } else {
        cell.syncButton.syncState = .syncing
      }
    } else {
      cell.syncButton.syncState = .noSync
      
      cell.syncHandler = { [weak cell] in
        cell?.syncHandler = nil
        
        PodcastTransferManager.shared.transfer(episode)
      }
    }
    
    return cell
  }
  
  override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    let header = Bundle.main.loadNibNamed("RecentPodcastsHeaderView", owner: nil, options: nil)?.first as! RecentPodcastsHeaderView
    
    header.label.text = libraryResultsController.sections?[section].name
    
    return header
  }
  
  override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    return 28.0
  }
  
  @IBAction func handleSegmentPress(_ sender: UISegmentedControl) {
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    let viewController = storyboard.instantiateViewController(withIdentifier: "PodcastsViewController")
    
    navigationController?.viewControllers = [viewController]
  }
}

//MARK: - NSFetchedResultsControllerDelegate

extension RecentPodcastsViewController: NSFetchedResultsControllerDelegate {
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
    }
  }
  
  func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    tableView.endUpdates()
  }
}
