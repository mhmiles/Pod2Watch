//
//  NowPlayingController.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 5/2/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import WatchKit
import Foundation
import ReactiveSwift
import enum Result.NoError
import AVFoundation
import CoreData

class NowPlayingController: WKInterfaceController {
  @IBOutlet weak var containerGroup: WKInterfaceGroup!
  @IBOutlet weak var progressBar: WKInterfaceGroup!
  @IBOutlet weak var currentLabel: WKInterfaceLabel!
  @IBOutlet weak var rateLabel: WKInterfaceLabel!
  @IBOutlet weak var remainingLabel: WKInterfaceLabel!
  @IBOutlet weak var podcastTitleLabel: WKInterfaceLabel!
  @IBOutlet weak var episodeTitleLabel: WKInterfaceLabel!
  @IBOutlet weak var playPauseButton: WKInterfaceButton!
  @IBOutlet weak var backgroundGroup: WKInterfaceGroup!
  
  fileprivate var wasPlaying = false
  
  private var deinitDisposable: ScopedDisposable<AnyDisposable>!
  
  private let player = AudioPlayer.shared
  
  override func awake(withContext context: Any?) {
    super.awake(withContext: context)

    crownSequencer.delegate = self

    let compositeDisposable = CompositeDisposable()

    compositeDisposable += player.currentItem.producer.startWithValues { [unowned self] _ in
      let episode = self.player.currentEpisode

      self.updateBackground(image: episode?.artworkImage.value)

      self.podcastTitleLabel.setText(episode?.podcast.title)
      self.episodeTitleLabel.setText(episode?.title)
    }

    compositeDisposable += player.offset.producer.debounce(0.25, on: QueueScheduler.main).startWithValues { [unowned self] _ in
      if self.wasPlaying {
        self.wasPlaying = false
        try? self.player.play()
      }
    }

    compositeDisposable += AudioPlayer.shared.isPlaying.producer.startWithValues { [unowned self] isPlaying in
      if isPlaying {
        self.playPauseButton.setBackgroundImage(#imageLiteral(resourceName: "Pause"))
      } else {
        self.playPauseButton.setBackgroundImage(#imageLiteral(resourceName: "Play"))
      }
    }

    compositeDisposable += player.offset.producer.combineLatest(with:
      player.duration.producer).startWithValues({ [unowned self] (currentTime, duration) in
        let sanitizedCurrentTime = currentTime.isNaN || currentTime.isInfinite ? 0 : currentTime
        let sanitizedDuration = duration.isNaN || duration.isInfinite ? 0 : duration

        self.updateTimeLabels(currentTime: sanitizedCurrentTime,
                              duration: sanitizedDuration)
      })

    deinitDisposable = ScopedDisposable(compositeDisposable)
  }
  
  override func willActivate() {
    crownSequencer.focus()
  }
  
  override func willDisappear() {
    player.updateStartTime()
  }
  
  private func updateBackground(image: UIImage?) {
    backgroundGroup.setBackgroundImage(image)
  }
  
  fileprivate func updateTimeLabels(currentTime: TimeInterval, duration: TimeInterval) {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .positional
    formatter.zeroFormattingBehavior = [ .pad ]
    
    if currentTime >= 60*60 {
      formatter.allowedUnits = [ .hour, .minute, .second ]
      
    } else {
      formatter.allowedUnits = [ .minute, .second ]
    }
    
    currentLabel.setText(formatter.string(from: currentTime))
    
    let remainingTime = duration-currentTime
    
    if remainingTime >= 60*60 {
      formatter.allowedUnits = [ .hour, .minute, .second ]
    } else {
      formatter.allowedUnits = [ .minute, .second ]
    }
    
    remainingLabel.setText(formatter.string(from: remainingTime).map({ "-\($0)" }))
    
    let progressRatio = duration == 0 ? 0 : max(0, currentTime/duration)
    progressBar.setWidth(contentFrame.width*CGFloat(progressRatio))
  }
  
  fileprivate func updateRateLabel() {
    let rate = player.rate ?? 1
    
    if rate == 1 || rate == 0 {
      rateLabel.setText(nil)
    } else {
      if rate == rate.rounded() {
        rateLabel.setText(String(format: "%dx", rate))
      } else {
        rateLabel.setText(String(format: "%.1fx", rate))
      }
    }
  }
  
  @IBAction func handlePlayPause() {
    do {
      try player.playPause()
    } catch {
      presentController(withName: "NoBluetooth", context: nil)
    }
    
    WKInterfaceDevice.current().play(.click)
  }
  
  @IBAction func handleBack() {
    WKInterfaceDevice.current().play(.click)
    
    player.advance(-15)
  }
  
  @IBAction func handleForward() {
    WKInterfaceDevice.current().play(.click)
    
    player.advance(15)
  }
  
  @IBAction func handleSpeedDown() {
    WKInterfaceDevice.current().play(.directionDown)
    
    player.setRate(player.rate - 0.1)
    updateRateLabel()
  }
  
  @IBAction func handleSpeedUp() {
    WKInterfaceDevice.current().play(.directionUp)
    
    player.setRate(player.rate + 0.1)
    updateRateLabel()
  }
  
  @IBAction func handleSeekTo() {
    WKInterfaceDevice.current().play(.click)
    
    presentController(withName: "Seek", context: nil)
  }
  
  @IBAction func handleDelete() {
    WKInterfaceDevice.current().play(.success)
    
    guard let episode = player.currentEpisode else {
      return
    }
    
    player.advanceToNextItem()
    PodcastTransferManager.shared.delete(episode)
  }
}

// MARK: - WKCrownDelegate

extension NowPlayingController: WKCrownDelegate {
  func crownDidRotate(_ crownSequencer: WKCrownSequencer?, rotationalDelta: Double) {
    if player.isPlaying.value {
      wasPlaying = true
      player.pause()
    }
    
    let delta = rotationalDelta*20*pow(1+rotationalDelta, 4)
    
    if delta == 0 {
      return
    }
    
    //Check to prevent playback reset
    if player.offset.value + delta > player.duration.value-0.1 {
      player.setCurrentTime(player.duration.value-0.1)
    } else {
      player.advance(delta)
    }
  }
}
