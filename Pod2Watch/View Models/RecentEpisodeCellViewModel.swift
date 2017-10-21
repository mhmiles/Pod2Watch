//
//  RecentEpisodeCellViewModel.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 10/20/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import Foundation
import ReactiveSwift
import enum Result.NoError
import UIKit

struct RecentEpisodeCellViewModel {
  let identifier: Int64
  let title: String?
  let secondaryLabelText: String?
  let syncHandler: () -> Void
  let syncState: SyncState
  let artworkProducer: SignalProducer<UIImage?, NoError>
}
