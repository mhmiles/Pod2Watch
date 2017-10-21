//
//  PodcastEpisodeCellViewModel.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 10/20/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import Foundation
import ReactiveSwift
import enum Result.NoError

struct PodcastEpisodeCellViewModel {  
  let identifier: Int64
  let title: String?
  let secondaryLabelText: String?
  let syncHandler: () -> Void
  let syncState: SyncState
}
