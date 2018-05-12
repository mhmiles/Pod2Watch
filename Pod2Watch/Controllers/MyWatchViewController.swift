//
//  MyWatchViewController.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 2/11/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import UIKit
import CoreData
import ReactiveSwift
import racAdditions
import WatchConnectivity

class MyWatchViewController: UITableViewController {
  var episodes: [TransferredEpisode]? {
    return fetchedResultsController.fetchedObjects
  }
  
  private func viewModel(at index: IndexPath) -> WatchEpisodeCellViewModel {
    return fetchedResultsController.object(at: index).watchEpisodeCellViewModel
  }
  
  lazy var fetchedResultsController: NSFetchedResultsController<TransferredEpisode> = {
    let request: NSFetchRequest<TransferredEpisode> = TransferredEpisode.fetchRequest()
    request.sortDescriptors = [NSSortDescriptor(key: #keyPath(TransferredEpisode.sortIndex),
                                                ascending: true)]
    request.predicate = NSPredicate(format: "shouldDelete == NO")
    
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
    
    navigationController?.navigationBar.prefersLargeTitles = true
  }
  
  @objc @IBAction func handleEditPress() {
    if tableView.isEditing {
      tableView.setEditing(false, animated: true)
      navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(handleEditPress))
    } else {
      tableView.setEditing(true, animated: true)
      navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(handleEditPress))
    }
  }
  
  // MARK: - Table view data source
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    return fetchedResultsController.sections?.count ?? 0
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return fetchedResultsController.sections![section].numberOfObjects
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard let cell = tableView.dequeueReusableCell(withIdentifier: "MyWatchCell", for: indexPath) as? MyWatchEpisodeCell else {
      abort()
    }
    
    cell.viewModel = viewModel(at: indexPath)
    
    return cell
  }
  
  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      PodcastTransferManager.shared.delete(fetchedResultsController.object(at: indexPath))
    }
  }
  
  override func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
    let episode = fetchedResultsController.object(at: indexPath)
    
    return episode.isTransferred ? "Delete" : "Cancel"
  }
  
  override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
    guard var episodes = episodes else {
      return
    }
    
    let episode = episodes.remove(at: fromIndexPath.row)
    episodes.insert(episode, at: to.row)
    
    for (index, episode) in episodes.enumerated() {
      episode.sortIndex = Int16(index)
    }
    
    PersistentContainer.saveContext()
    
    PodcastTransferManager.shared.sendSortOrder()
  }
  
  override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
    return true
  }
}

// MARK: - NSFetchedResultsControllerDelegate

extension MyWatchViewController: NSFetchedResultsControllerDelegate {
  func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    tableView.beginUpdates()
  }
  
  func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                  didChange anObject: Any,
                  at indexPath: IndexPath?,
                  for type: NSFetchedResultsChangeType,
                  newIndexPath: IndexPath?) {
    switch type {
    case .insert:
      tableView.insertRows(at: [newIndexPath!],
                           with: .fade)
      
    case .delete:
      tableView.deleteRows(at: [indexPath!],
                           with: .fade)
      
    case .update:
      tableView.reloadRows(at: [indexPath!],
                           with: .fade)
      
    default:
      break
    }
  }
  
  func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    tableView.endUpdates()
  }
}
