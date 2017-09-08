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

private let reuseIdentifier = "MyPodcastsCell"
private let searchToken = NSString(string: "c6816e681737dea7e15642b7887a64d8fce71aa2")
private let searchBarBottomOffset = CGPoint(x: 0.0, y: 42.0)

class MyPodcastsViewController: UIViewController, IGListAdapterDataSource {
  @IBOutlet weak var collectionView: IGListCollectionView!

  lazy var adapter: IGListAdapter = {
    let adapter = IGListAdapter(updater: IGListAdapterUpdater(), viewController: self, workingRangeSize: 0)
    adapter.scrollViewDelegate = self

    return adapter
  }()

  var podcastsViewController: MyPodcastsViewController!
  var recentViewController: UITableViewController!

  @IBOutlet weak var segmentedTitle: UISegmentedControl!

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

  fileprivate weak var searchBar: UISearchBar? {
    didSet {
      searchBar?.delegate = self
    }
  }

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

    segmentedTitle.setTitleTextAttributes([NSFontAttributeName: UIFont.systemFont(ofSize: 16)],
                                          for: .normal)

    collectionView.setContentOffset(searchBarBottomOffset, animated: false)

    //Force library load to prevent infinite recursion
    _ = libraryResultsController

    adapter.collectionView = collectionView
    adapter.dataSource = self

    NotificationCenter.default.addObserver(forName: InMemoryContainer.PodcastLibraryDidReload,
                                           object: InMemoryContainer.shared,
                                           queue: OperationQueue.main) { [weak self] _ in
                                            try! self?.libraryResultsController.performFetch()
                                            self?.adapter.reloadData()
    }
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  @IBAction func handleSegmentPress(_ sender: UISegmentedControl) {
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    let viewController = storyboard.instantiateViewController(withIdentifier: "RecentViewController")

    navigationController?.viewControllers = [viewController]
  }

  @IBAction func requestLibraryAccess() {
    MPMediaLibrary.requestAuthorization { (status) in
      if status == .authorized {
        InMemoryContainer.shared.reloadPodcastLibrary()
      } else {
      }

      self.adapter.reloadData()
    }
  }

  @IBAction func openSettings() {
    guard let settingsURL = URL(string: UIApplicationOpenSettingsURLString) else {
      return
    }

    UIApplication.shared.open(settingsURL)
  }

  @IBAction func openPodcasts() {
    let podcastsURL = URL(string: "podcast://")!
    UIApplication.shared.open(podcastsURL)
  }

  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    let cell = sender as! UICollectionViewCell
    let indexPath = collectionView!.indexPath(for: cell)!

    guard let podcastsEpisodesController = segue.destination as? MyPodcastsEpisodesViewController else {
      return
    }

    let podcast = libraryResultsController.fetchedObjects?[indexPath.section-1]
    podcastsEpisodesController.podcastTitle = podcast?.title
  }

  // MARK: - IGListAdapterDataSource

  func objects(for listAdapter: IGListAdapter) -> [IGListDiffable] {
    guard let podcasts = libraryResultsController.fetchedObjects,
      podcasts.count > 0 || titleSearchQuery != nil else {
        return []
    }

    return [searchToken] + podcasts
  }

  func listAdapter(_ listAdapter: IGListAdapter, sectionControllerFor object: Any) -> IGListSectionController {
    if let string = object as? NSString, string == searchToken {
      return IGListSingleSectionController(storyboardCellIdentifier: "SearchBar",
                                           configureBlock: { [unowned self] (item, cell) in
                                            guard let searchBarCell = cell as? SearchBarCell else {
                                              return
                                            }

                                            self.searchBar = searchBarCell.searchBar
        }, sizeBlock: { (_, context) -> CGSize in
          guard let context = context else {
            return CGSize.zero
          }

          return CGSize(width: context.containerSize.width, height: 40.0)
      })
    }

    return IGListSingleSectionController(storyboardCellIdentifier: "PodcastCell",
                                         configureBlock: { (item, cell) in
                                          guard let podcast = item as? LibraryPodcast,
                                            let podcastCell = cell as? PodcastCell else {
                                              return
                                          }

                                          podcastCell.imageView.rac_image <~ podcast.podcastArtworkProducer
    }, sizeBlock: { (_, context) -> CGSize in
      guard let context = context else {
        return CGSize.zero
      }

      let width = context.containerSize.width/2 - 1
      return CGSize(width: width, height: width)
    })
  }

  func emptyView(for listAdapter: IGListAdapter) -> UIView? {
    let authorizationStatus = MPMediaLibrary.authorizationStatus()

    switch authorizationStatus {
    case .authorized:
      return UINib(nibName: "OpenPodcastsView", bundle: nil).instantiate(withOwner: self, options: nil).first as? UIView

    case .restricted:
      fallthrough
    case .denied:
      return UINib(nibName: "NoAccessView", bundle: nil).instantiate(withOwner: self, options: nil).first as? UIView

    case .notDetermined:
      return UINib(nibName: "RequestAccessView", bundle: nil).instantiate(withOwner: self, options: nil).first as? UIView
    }
  }
}

// MARK: - NSFetchedResultsControllerDelegate

extension MyPodcastsViewController: NSFetchedResultsControllerDelegate {
  func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    adapter.reloadData()
  }
}

// MARK: - UISearchBarDelegate

extension MyPodcastsViewController: UISearchBarDelegate {
  func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
    titleSearchQuery = searchText
  }
}

// MARK: - UIScrollViewDelegate

extension MyPodcastsViewController: UIScrollViewDelegate {
  func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    searchBar?.resignFirstResponder()
  }

  func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    if decelerate == false {
      handleSearchBarVisiblity()
    }
  }

  func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    handleSearchBarVisiblity()
  }

  private func handleSearchBarVisiblity() {
    let scrollView = collectionView!
    let offset = scrollView.contentOffset

    if offset.y < -44 {
      scrollView.setContentOffset(CGPoint(x: 0, y: -64), animated: true)
      searchBar?.becomeFirstResponder()
    } else if offset.y < -24 {
      scrollView.setContentOffset(CGPoint(x: 0, y: -22), animated: true)
    }
  }
}
