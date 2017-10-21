//
//  MyPodcastsEpisodeCell.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 2/10/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import UIKit

class MyPodcastsEpisodeCell: UITableViewCell {
  @IBOutlet weak var titleLabel: UILabel!
  @IBOutlet weak var durationLabel: UILabel!
  @IBOutlet weak var syncButton: SyncButton!

  var viewModel: PodcastEpisodeCellViewModel? {
    didSet {
      titleLabel.text = viewModel?.title
      durationLabel.text = viewModel?.secondaryLabelText
      syncButton.syncState = viewModel?.syncState
    }
  }

  @IBAction func handleSyncPress(button: UIButton) {
    viewModel?.syncHandler()
  }

  override func prepareForReuse() {
    viewModel = nil
  }
}
