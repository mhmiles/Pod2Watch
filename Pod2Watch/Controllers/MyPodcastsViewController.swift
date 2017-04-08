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

private let reuseIdentifier = "MyPodcastsCell"

class MyPodcastsViewController: UIViewController, IGListAdapterDataSource {
  @IBOutlet weak var collectionView: IGListCollectionView!
  
  lazy var adapter: IGListAdapter = {
    return IGListAdapter(updater: IGListAdapterUpdater(), viewController: self, workingRangeSize: 0)
  }()
  
  var podcasts: [LibraryPodcastEpisode]!
  
  var podcastsViewController: MyPodcastsViewController!
  var recentViewController: UITableViewController!
  
  @IBOutlet weak var segmentedTitle: UISegmentedControl!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    segmentedTitle.setTitleTextAttributes([NSFontAttributeName: UIFont.systemFont(ofSize: 16)],
                                          for: .normal)
    
    loadPodcasts()
    
    adapter.collectionView = collectionView
    adapter.dataSource = self
  }
  
  fileprivate func loadPodcasts() {
    let request: NSFetchRequest<LibraryPodcastEpisode> = LibraryPodcastEpisode.fetchRequest()
    request.sortDescriptors = [NSSortDescriptor(key: "podcastTitleWithoutThe", ascending: true)]
    
    let episodes = try! InMemoryContainer.shared.viewContext.fetch(request)
    podcasts = episodes.reduce([], { (accum, episode) -> [LibraryPodcastEpisode] in
      if accum.last?.podcastTitle == episode.podcastTitle {
        return accum
      } else {
        return accum + [episode]
      }
    })
  }
  
  @IBAction func handleSegmentPress(_ sender: UISegmentedControl) {
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    let viewController = storyboard.instantiateViewController(withIdentifier: "RecentViewController")
    
    navigationController?.viewControllers = [viewController]
  }
  
  @IBAction func requestLibraryAccess() {
    MPMediaLibrary.requestAuthorization { (status) in
      if status == .authorized {
        InMemoryContainer.shared.loadPodcastLibrary()
//        InMemoryContainer.saveContext()
        self.loadPodcasts()
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
    
    let podcastsEpisodesController = segue.destination as! MyPodcastsEpisodesViewController
    
    podcastsEpisodesController.podcastTitle = podcasts[indexPath.section].podcastTitle ?? ""
  }
  
  //MARK: IGListAdapterDataSource
  
  func objects(for listAdapter: IGListAdapter) -> [IGListDiffable] {
    return podcasts ?? []
  }
  
  func listAdapter(_ listAdapter: IGListAdapter, sectionControllerFor object: Any) -> IGListSectionController {
    return PodcastSectionController()
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

extension NSString {
  func trimmingThe() -> String {
    if lowercased.hasPrefix("the ") {
      return substring(from: 4).trimmingCharacters(in: CharacterSet.whitespaces)
    } else {
      return self as String
    }
  }
  
  @objc func compareWithoutThe(_ string: NSString) -> ComparisonResult {
    return trimmingThe().compare(string.trimmingThe())
  }
}
