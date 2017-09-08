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

  var syncHandler: (() -> Void)?

  override func awakeFromNib() {
    super.awakeFromNib()
    // Initialization code
  }

  override func setSelected(_ selected: Bool, animated: Bool) {
    super.setSelected(selected, animated: animated)

    // Configure the view for the selected state
  }

  @IBAction func handleSyncPress(button: UIButton) {
    if let syncHandler = syncHandler {
      syncHandler()
    }
  }

  override func prepareForReuse() {
    syncButton.isEnabled = true
    syncHandler = nil
  }
}
