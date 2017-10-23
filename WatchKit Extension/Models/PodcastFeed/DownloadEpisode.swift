//
//  DownloadEpisode.swift
//  Pod2Watch WatchKit Extension
//
//  Created by Miles Hollingsworth on 10/21/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import Foundation

struct DownloadEpisode {
    let persistentID: Int64
    let title: String
    let podcastTitle: String
    let playbackDuration: TimeInterval
    let releaseDate: Date
    let mediaURL: URL
    let artworkURL: URL
}
