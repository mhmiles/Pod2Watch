//
//  PodcastsTableRowController.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 2/10/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import WatchKit
import ReactiveSwift

class PodcastsTableRowController: NSObject {
  @IBOutlet var backgroundGroup: WKInterfaceGroup!
  @IBOutlet var artworkImage: WKInterfaceImage!
  @IBOutlet var podcastTitleLabel: WKInterfaceLabel!
  @IBOutlet var epiosodeTitleLabel: WKInterfaceLabel!

  @IBOutlet var progressBar: WKInterfaceGroup!
  var progressBarWidth: CGFloat!

  var artworkImageDisposable: Disposable?

  var isSelected = false {
    didSet {
      if isSelected {
        backgroundGroup.setBackgroundImage(#imageLiteral(resourceName: "Now Playing Border"))
        backgroundGroup.setCornerRadius(6)
      } else {
        backgroundGroup.setBackgroundImage(nil)
        backgroundGroup.setCornerRadius(6)
      }
    }
  }

  func setProgressBarCompletion(_ fraction: TimeInterval) {
    progressBar.setWidth(progressBarWidth*CGFloat(fraction))
  }

  deinit {
    artworkImageDisposable?.dispose()
  }
}
