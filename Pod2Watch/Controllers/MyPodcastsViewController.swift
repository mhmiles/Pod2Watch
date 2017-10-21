//
//  MyPodcastsViewController.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 2/10/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import UIKit
import Alamofire
import IGListKit
import CoreData
import MediaPlayer.MPMediaLibrary
import ReactiveSwift

private let openPodcastsToken = "396c19ce-e6dc-463c-9088-4cbf10fc5381" as NSString

class MyPodcastsViewController: UICollectionViewController, ListAdapterDataSource {
  lazy var adapter: ListAdapter = ListAdapter(updater: ListAdapterUpdater(), viewController: self, workingRangeSize: 0)
  
  private var podcasts: [LibraryPodcast]? {
    return libraryResultsController.fetchedObjects
  }
  
  private var viewModels: [PodcastCellViewModel]? {
    return podcasts?.map({ $0.podcastCellViewModel })
  }
  
  var podcastsViewController: MyPodcastsViewController!
  var recentViewController: UITableViewController!
  
  fileprivate lazy var libraryResultsController: NSFetchedResultsController<LibraryPodcast> = {
    let request: NSFetchRequest<LibraryPodcast> = LibraryPodcast.fetchRequest()
    
    request.sortDescriptors = [NSSortDescriptor(key: #keyPath(LibraryPodcast.titleWithoutThe),
                                                ascending: true)]
    
    let context = InMemoryContainer.shared.viewContext
    let controller = NSFetchedResultsController<LibraryPodcast>(fetchRequest: request,
                                                                managedObjectContext: context,
                                                                sectionNameKeyPath: nil,
                                                                cacheName: nil)
    
    try! controller.performFetch()
    controller.delegate = self
    
    return controller
  }()
  
  fileprivate var titleSearchQuery: String? {
    didSet {
      if let titleSearchQuery = self.titleSearchQuery, titleSearchQuery.characters.count > 0 {
        libraryResultsController.fetchRequest.predicate = NSPredicate(format: "title CONTAINS[cd] %@", titleSearchQuery)
      } else {
        libraryResultsController.fetchRequest.predicate = nil
      }
      
      try! libraryResultsController.performFetch()
      adapter.performUpdates(animated: true, completion: nil)
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    //Load library here
    _ = libraryResultsController
    
    adapter.collectionView = collectionView
    adapter.dataSource = self
    adapter.collectionViewDelegate = self
    adapter.scrollViewDelegate = self
    
    NotificationCenter.default.addObserver(forName: .podcastLibraryDidReload,
                                           object: InMemoryContainer.shared,
                                           queue: nil) { [weak self] _ in
                                            try! self?.libraryResultsController.performFetch()
                                            self?.adapter.performUpdates(animated: true, completion: nil)
    }
    
    let searchController = UISearchController(searchResultsController: nil)
    searchController.hidesNavigationBarDuringPresentation = false
    navigationItem.searchController = searchController
    
    let searchBar = searchController.searchBar
    searchBar.delegate = self
    searchBar.tintColor = UIColor(red:0.40, green:0.19, blue:0.83, alpha:1.0)
    
    navigationController?.navigationBar.prefersLargeTitles = true
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self)
  }
  
  @IBAction func requestLibraryAccess() {
    MPMediaLibrary.requestAuthorization { (status) in
      if status == .authorized {
        self.adapter.performUpdates(animated: true, completion: nil)
      } else {
        self.adapter.reloadData()
      }
    }
  }
  
  @IBAction func openSettings() {
    guard let settingsURL = URL(string: UIApplicationOpenSettingsURLString) else {
      return
    }
    
    UIApplication.shared.open(settingsURL)
  }
  
  @IBAction func openPodcasts() {
    UIApplication.shared.openPodcasts()
  }
  
  override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    guard let podcasts = podcasts, indexPath.section < podcasts.count else {
      return
    }
    
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    
    guard let episodesController = storyboard.instantiateViewController(withIdentifier: "MyPodcastsEpisodesViewController") as? MyPodcastsEpisodesViewController else {
      fatalError()
    }
    
    episodesController.podcastTitle = podcasts[indexPath.section].title ?? ""
    navigationController?.pushViewController(episodesController, animated: true)
  }
  
  // MARK: - ListAdapterDataSource
  
  func objects(for listAdapter: ListAdapter) -> [ListDiffable] {
    guard let viewModels = viewModels, viewModels.count > 0 else {
        return []
    }
    
    return viewModels + [openPodcastsToken]
  }
  
  func listAdapter(_ listAdapter: ListAdapter, sectionControllerFor object: Any) -> ListSectionController {
    if let token = object as? NSString {
      switch token {
      case openPodcastsToken:
        let controller = OpenPodcastsSectionController()
        controller.delegate = self
        return controller
        
      default:
        fatalError()
      }
    }

    return PodcastSectionController()
  }
  
  func emptyView(for listAdapter: ListAdapter) -> UIView? {
    let authorizationStatus = MPMediaLibrary.authorizationStatus()
    
    switch authorizationStatus {
    case .authorized:
      if InMemoryContainer.shared.viewContext.registeredObjects.count > 0 {
        return UINib(nibName: "EmptySearchView", bundle: nil).instantiate(withOwner: self, options: nil).first as? UIView
      } else {
        return UINib(nibName: "OpenPodcastsView", bundle: nil).instantiate(withOwner: self, options: nil).first as? UIView
      }
      
    case .restricted:
      fallthrough
    case .denied:
      return UINib(nibName: "NoAccessView", bundle: nil).instantiate(withOwner: self, options: nil).first as? UIView
      
    case .notDetermined:
      return UINib(nibName: "RequestAccessView", bundle: nil).instantiate(withOwner: self, options: nil).first as? UIView
    }
  }
  
  //MARK: - UIScrollViewDelegate
  
  override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    if decelerate == false {
      handleKeyboardVisibility(offset: scrollView.contentOffset)
    }
  }
  
  override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    handleKeyboardVisibility(offset: scrollView.contentOffset)
  }
  
  private func handleKeyboardVisibility(offset: CGPoint) {
    if offset.y == 0 {
      navigationItem.searchController?.searchBar.becomeFirstResponder()
    }
  }
}

// MARK: - NSFetchedResultsControllerDelegate

extension MyPodcastsViewController: NSFetchedResultsControllerDelegate {
  func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    adapter.performUpdates(animated: true, completion: nil)
  }
}

// MARK: - UISearchBarDelegate

extension MyPodcastsViewController: UISearchBarDelegate {
  func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
    searchBar.text = titleSearchQuery
  }
  
  func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
    titleSearchQuery = searchText
  }
}

extension MyPodcastsViewController: OpenPodcastsSectionControllerDelegate {
  func handleOpenPodcasts() {
    openPodcasts()
  }
}
