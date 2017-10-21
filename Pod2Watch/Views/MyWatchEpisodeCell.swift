//
//  MyWatchEpisodeCell.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 2/11/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import UIKit

class MyWatchEpisodeCell: UITableViewCell {
  @IBOutlet weak var titleLabel: UILabel!
  @IBOutlet weak var durationLabel: UILabel!
  @IBOutlet weak var artworkView: UIImageView!
  @IBOutlet weak var syncButton: SyncButton!

  override func awakeFromNib() {
    super.awakeFromNib()
    // Initialization code
  }
  
  var viewModel: WatchEpisodeCellViewModel? {
    didSet {
      titleLabel.text = viewModel?.title
      durationLabel.text = viewModel?.secondaryLabelText
      syncButton.syncState = viewModel?.syncState
      
      artworkView.image = viewModel?.artworkImage
    }
  }

  override func setSelected(_ selected: Bool, animated: Bool) {
    super.setSelected(selected, animated: animated)

    // Configure the view for the selected state
  }

  override func prepareForReuse() {
    super.prepareForReuse()

    syncButton.syncState = nil
  }
}
