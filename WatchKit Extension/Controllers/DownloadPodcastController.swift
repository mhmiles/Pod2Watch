//
//  DownloadPodcastController.swift
//  Pod2Watch WatchKit Extension
//
//  Created by Miles Hollingsworth on 10/21/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import WatchKit
import Foundation
import Alamofire

class DownloadPodcastController: WKInterfaceController {
  
  var podcasts: [PodcastFeedProvider]? {
    didSet {
      spinner.setHidden(true)
      setupRows()
    }
  }
  
  @IBOutlet var spinner: WKInterfaceGroup!
  @IBOutlet var podcastsTable: WKInterfaceTable!
  
  override func awake(withContext context: Any?) {
    setupRows()
  }
  
  override func willActivate() {
    if podcasts == nil, isSearching == false {
      spinner.setHidden(false)
        downloadTopPodcasts()
    }
  }
  
  private var isSearching =  false
  
  func setupRows() {
    let podcastCount = podcasts?.count ?? 0
    podcastsTable.setNumberOfRows(podcastCount+1, withRowType: "Podcast")
    
    let searchController = podcastsTable.rowController(at: 0) as! DownloadPodcastRowController
    searchController.backgroundGroup.setBackgroundColor(.podcasts)
    searchController.titleLabel.setText("Search")
    searchController.image.setHidden(false)
    searchController.rightPadding.setHidden(false)
    
    guard let podcasts = podcasts else {
      return
    }
    
    spinner.setHidden(true)
    
    for (index, podcast) in podcasts.enumerated() {
      let rowController = podcastsTable.rowController(at: index+1) as! DownloadPodcastRowController
      
      rowController.titleLabel.setText(podcast.name)
    }
  }
  
  override func table(_ table: WKInterfaceTable, didSelectRowAt rowIndex: Int) {
    if rowIndex == 0 {
      isSearching = true
      
      presentTextInputController(withSuggestions: nil,
                                 allowedInputMode: .allowEmoji,
                                 completion: { (result) -> Void in
                                  self.isSearching = false
                                  
                                  if let text = result?.first as? String {
                                    self.podcasts = nil
                                    self.spinner.setHidden(false)
                                    PodcastDownloadManager.shared.handleSearch(term: text) { (podcasts, error) in
                                      self.podcasts = podcasts
                                    }
                                  } else if self.podcasts == nil {
                                    self.spinner.setHidden(false)
                                    self.downloadTopPodcasts()
                                  }
      })
      
      return
    }
    
    guard let podcasts = podcasts else {
      return
    }
    
    let podcast = podcasts[rowIndex-1]
    pushController(withName: "DownloadEpisode", context: podcast)
  }
  
  private func downloadTopPodcasts() {
    PodcastDownloadManager.shared.downloadTopPodcasts(completion: { (podcasts, error) in
      guard let podcasts = podcasts else {
        self.pushController(withName: "PodcastListError",
                                        context: nil)
        return
      }
      
      self.podcasts = podcasts
    })
  }
}
