//
//  RecentEpisodeCell.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 2/15/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import UIKit

class RecentEpisodeCell: UITableViewCell {
  @IBOutlet weak var titleLabel: UILabel!
  @IBOutlet weak var artworkView: UIImageView!
  @IBOutlet weak var durationLabel: UILabel!
  @IBOutlet weak var releaseDateLabel: UILabel!
  @IBOutlet weak var timeRemainingLabel: UILabel!
  @IBOutlet weak var syncButton: SyncButton!
  
  var syncHandler: (() -> Void)?
  
  @IBAction func handleSyncPress(button: UIButton) {
    if let syncHandler = syncHandler {
      syncHandler()
    }
  }
}
