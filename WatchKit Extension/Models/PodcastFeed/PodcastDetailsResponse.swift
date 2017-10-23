//
//  PodcastDetailsResponse.swift
//  Pod2Watch WatchKit Extension
//
//  Created by Miles Hollingsworth on 10/21/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import Foundation

struct PodcastDetailsResponse: Codable {
  let resultCount: Int
  let results: [PodcastDetails]
}