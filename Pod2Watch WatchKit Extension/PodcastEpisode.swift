//
//  PodcastEpisode.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 4/3/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import Foundation

extension PodcastEpisode {
  var fileURL: URL {
    return URL(string: fileURLString!)!
  }
}
