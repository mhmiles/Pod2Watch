//
//  RecentEpisodeCell.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 2/15/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import UIKit
import ReactiveSwift
import enum Result.NoError

class RecentEpisodeCell: UITableViewCell {
  @IBOutlet weak var titleLabel: UILabel!
  @IBOutlet weak var artworkView: UIImageView!
  @IBOutlet weak var durationLabel: UILabel!
  @IBOutlet weak var releaseDateLabel: UILabel!
  @IBOutlet weak var timeRemainingLabel: UILabel!
  @IBOutlet weak var syncButton: SyncButton!

  var viewModel: RecentEpisodeCellViewModel? {
    didSet {
      titleLabel.text = viewModel?.title
      durationLabel.text = viewModel?.secondaryLabelText
      syncButton.syncState = viewModel?.syncState
    
        let artworkProducer = viewModel?.artworkProducer ?? SignalProducer<UIImage?, NoError>(value: nil)
        artworkView.rac_image <~ artworkProducer
    }
  }

  @IBAction func handleSyncPress(button: UIButton) {
    viewModel?.syncHandler()
  }
  
  override func prepareForReuse() {
    viewModel = nil
  }
}
