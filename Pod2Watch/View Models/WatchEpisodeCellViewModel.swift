//
//  WatchEpisodeCellViewModel.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 10/20/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import UIKit
import ReactiveSwift
import enum Result.NoError

struct WatchEpisodeCellViewModel {
  let identifier: Int64
  let title: String?
  let secondaryLabelText: String?
  let syncState: SyncState?
  let artworkImage: UIImage?
}
