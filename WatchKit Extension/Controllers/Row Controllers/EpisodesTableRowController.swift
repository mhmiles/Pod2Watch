//
//  EpisodesTableRowController.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 2/10/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import WatchKit
import ReactiveSwift

class EpisodesTableRowController: NSObject {
  @IBOutlet var backgroundGroup: WKInterfaceGroup!
  @IBOutlet var backgroundImageGroup: WKInterfaceGroup!
  @IBOutlet var artworkImage: WKInterfaceImage!
  @IBOutlet var podcastTitleLabel: WKInterfaceLabel!
  @IBOutlet var epiosodeTitleLabel: WKInterfaceLabel!

  @IBOutlet var progressBar: WKInterfaceGroup!
  var progressBarWidth: CGFloat!

  var artworkImageDisposable: Disposable?

  var isSelected = false {
    didSet {
      if isSelected {
        backgroundImageGroup.setBackgroundImage(#imageLiteral(resourceName: "Active Border"))
      } else {
        backgroundImageGroup.setBackgroundImage(nil)
      }
    }
  }
  
  var isSelectable = true {
    didSet {
      if isSelectable {
        backgroundGroup.setBackgroundImage(nil)
        backgroundGroup.setBackgroundColor(UIColor(red:0.13, green:0.13, blue:0.13, alpha:1.0))
      } else {
        backgroundGroup.setBackgroundImage(#imageLiteral(resourceName: "Dashed Border"))
        backgroundGroup.setBackgroundColor(UIColor.clear)
      }
    }
  }
  
  func configure(withEpisode episode: Episode, barWidth: CGFloat) {
    podcastTitleLabel.setText(episode.podcast.title)
    epiosodeTitleLabel.setText(episode.title)
    
    artworkImageDisposable = episode.artworkImage.producer.startWithValues(artworkImage.setImage)
    
    progressBarWidth = barWidth
    
    if let _ = episode.fileURL {
      setProgressBarCompletion(episode.startTime/max(1, episode.playbackDuration))
    } else if episode.isDownload {
      setProgressBarCompletion(episode.downloadProgress)
    }

    
    isSelectable = episode.fileURL != nil
  }

  func setProgressBarCompletion(_ fraction: TimeInterval) {
    progressBar.setWidth(progressBarWidth*CGFloat(fraction))
  }

  deinit {
    artworkImageDisposable?.dispose()
  }
}
