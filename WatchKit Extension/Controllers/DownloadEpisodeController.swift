//
//  DownloadEpisodeController.swift
//  Pod2Watch WatchKit Extension
//
//  Created by Miles Hollingsworth on 10/21/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import WatchKit
import Foundation
import Alamofire
import SWXMLHash
import ReactiveSwift

class DownloadEpisodeController: WKInterfaceController {
  var episodes: [DownloadEpisode]? {
    didSet {
      setupRows()
    }
  }

  @IBOutlet var episodesTable: WKInterfaceTable!
  @IBOutlet var spinner: WKInterfaceGroup!
  
  override func awake(withContext context: Any?) {
    guard let podcast = context as AnyObject as? PodcastFeedProvider else {
      fatalError("No podcast")
    }
    
    setTitle(podcast.name)
    
    if let _ = podcast.feedURL {
      PodcastDownloadManager.shared.getEpisodes(podcast: podcast) { (episodes, error) in
        guard let episodes = episodes else {
          print(error as Any)
          return
        }
        
        self.episodes = episodes
      }
    } else {
      PodcastDownloadManager.shared.getFeedURL(id: podcast.collectionId) { (podcast, error) in
        guard let podcast = podcast else {
          print(error as Any)
          return
        }
        
        PodcastDownloadManager.shared.getEpisodes(podcast: podcast) { (episodes, error) in
          guard let episodes = episodes else {
            print(error as Any)
            return
          }
          
          self.episodes = episodes
        }
        
      }
    }
  }
  
  func setupRows() {
    spinner.setHidden(true)
    
    guard let episodes = episodes else {
      episodesTable.setNumberOfRows(0, withRowType: "EpisodesError")
      
      return
    }
    
    episodesTable.setNumberOfRows(episodes.count, withRowType: "Episode")
    
    for (index, episode) in episodes.enumerated() {
      let rowController = episodesTable.rowController(at: index) as! DownloadEpisodeRowController
      
      rowController.titleLabel.setText(episode.title)
    }
  }
  
  override func table(_ table: WKInterfaceTable, didSelectRowAt rowIndex: Int) {
    guard let episodes = episodes else {
      return
    }
    
    try? PodcastTransferManager.shared.download(episode: episodes[rowIndex])
    popToRootController()
  }
}

protocol PodcastFeedProvider {
  var name: String { get }
  var collectionId: Int { get }
  var feedURL: URL? { get }
  var artworkURL: URL { get }
}
