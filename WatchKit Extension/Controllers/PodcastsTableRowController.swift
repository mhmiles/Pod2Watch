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
  
  func setProgressBarCompletion(_ fraction: TimeInterval) {
    progressBar.setWidth(progressBarWidth*CGFloat(fraction))
  }
  
  deinit {
    artworkImageDisposable?.dispose()
  }
}
