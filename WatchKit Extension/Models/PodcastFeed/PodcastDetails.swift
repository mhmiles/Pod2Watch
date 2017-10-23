//
//  PodcastDetails.swift
//  Pod2Watch WatchKit Extension
//
//  Created by Miles Hollingsworth on 10/21/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import Foundation

struct PodcastDetails: Codable {
    let collectionName: String
    let collectionId: Int
  let feedUrl: String?
  let artworkUrl600: String
}

extension PodcastDetails: PodcastFeedProvider {
  var artworkURL: URL {
    return URL(string: artworkUrl600)!
  }
  
  var feedURL: URL? {
    return feedUrl.flatMap { URL(string: $0) }
  }
  
  var name: String {
    return collectionName
  }
}
