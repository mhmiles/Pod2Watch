//
//  TopPodcastDetails.swift
//  Pod2Watch WatchKit Extension
//
//  Created by Miles Hollingsworth on 10/22/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import Foundation

struct TopPodcastDetails: Codable {
    let name: String
    let id: String
  let artworkUrl100: String
}

extension TopPodcastDetails: PodcastFeedProvider {
  var artworkURL: URL {
    return URL(string: artworkUrl100)!
  }
  
  var feedURL: URL? {
   return nil
  }
  
  var collectionId: Int {
    return Int(id)!
  }
}
