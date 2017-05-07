//
//  PodcastsTableRowController.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 2/10/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import WatchKit

class PodcastsTableRowController: NSObject {
  @IBOutlet var artworkImage: WKInterfaceImage!
  @IBOutlet var podcastTitleLabel: WKInterfaceLabel!
  @IBOutlet var epiosodeTitleLabel: WKInterfaceLabel!
  
  @IBOutlet var progressBar: WKInterfaceGroup!
  var progressBarWidth: CGFloat!
  
  func setProgressBarCompletion(_ fraction: TimeInterval) {
    progressBar.setWidth(progressBarWidth*CGFloat(fraction))
  }
}
