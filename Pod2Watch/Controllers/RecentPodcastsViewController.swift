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

  fileprivate lazy var fetchedResultsController: NSFetchedResultsController<LibraryPodcastEpisode> = {
    let request: NSFetchRequest<LibraryPodcastEpisode> = LibraryPodcastEpisode.fetchRequest()
    request.sortDescriptors = [NSSortDescriptor(key: "releaseDate", ascending: false)]
    
    let controller = NSFetchedResultsController(fetchRequest: request,
                                                managedObjectContext: InMemoryContainer.shared.viewContext,
                                                sectionNameKeyPath: "releaseDateLabel",
                                                cacheName: nil)
    
    try! controller.performFetch()
    controller.delegate = self
    
    return controller
  }()
  
  fileprivate lazy var syncResultsController: NSFetchedResultsController<PodcastEpisode> = {
    let request: NSFetchRequest<PodcastEpisode> = PodcastEpisode.fetchRequest()
    request.sortDescriptors = [NSSortDescriptor(key: "releaseDate", ascending: false)]
    
    let controller = NSFetchedResultsController<PodcastEpisode>(fetchRequest: request,
                                                                managedObjectContext: PersistentContainer.shared.viewContext,
                                                                sectionNameKeyPath: nil,
                                                                cacheName: nil)
    
    controller.delegate = self
    
    return controller
  }()
  
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    segmentedTitle.setTitleTextAttributes([NSFontAttributeName: UIFont.systemFont(ofSize: 16)],
                                          for: .normal)
    
    try! syncResultsController.performFetch()
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  // MARK: - Table view data source
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    return fetchedResultsController.sections?.count ?? 0
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return fetchedResultsController.sections?[section].numberOfObjects ?? 0
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "RecentEpisodeCell", for: indexPath) as! RecentEpisodeCell
    
    let episode = fetchedResultsController.object(at: indexPath)
    
    cell.artworkView.rac_image <~ episode.podcastArtworkProducer
    
    cell.titleLabel.text = episode.episodeTitle
    cell.durationLabel.text = episode.recentSecondaryLabelText
    
    if let synced = syncResultsController.fetchedObjects?.first(where: { $0.podcastID == episode.podcastID }) {
      if synced.shouldDelete {
        cell.syncButton.syncState = .pending
      } else if synced.isTransferred {
        cell.syncButton.syncState = .synced
      } else {
        cell.syncButton.syncState = .syncing
      }
    } else {
      cell.syncButton.syncState = .noSync
      
      cell.syncHandler = {
        PodcastTransferManager.shared.transfer(episode)
      }
    }
    
    return cell
  }
  
  override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    let header = Bundle.main.loadNibNamed("RecentPodcastsHeaderView", owner: nil, options: nil)?.first as! RecentPodcastsHeaderView
    
    header.label.text = fetchedResultsController.sections?[section].name
    
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

extension RecentPodcastsViewController: NSFetchedResultsControllerDelegate {
  func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    tableView.beginUpdates()
  }
  
  func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
    if controller == syncResultsController,
      let episode = anObject as? PodcastEpisode,
      let existing = fetchedResultsController.fetchedObjects?.first(where: { $0.podcastID == episode.podcastID }),
      let existingIndexPath = fetchedResultsController.indexPath(forObject: existing) {
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
    } else if controller == fetchedResultsController {
      print(anObject)
    }
  }
  
  func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    tableView.endUpdates()
  }
}
