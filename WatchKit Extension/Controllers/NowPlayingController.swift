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

class NowPlayingController: WKInterfaceController {
  @IBOutlet weak var containerGroup: WKInterfaceGroup!
  @IBOutlet weak var progressBar: WKInterfaceGroup!
  @IBOutlet weak var currentLabel: WKInterfaceLabel!
  @IBOutlet weak var rateLabel: WKInterfaceLabel!
  @IBOutlet weak var remainingLabel: WKInterfaceLabel!
  @IBOutlet weak var podcastTitleLabel: WKInterfaceLabel!
  @IBOutlet weak var episodeTitleLabel: WKInterfaceLabel!
  @IBOutlet weak var playPauseButton: WKInterfaceButton!
  @IBOutlet weak var volumeSlider: WKInterfaceSlider!
  @IBOutlet var volumeSliderBackground: WKInterfaceGroup!
  
  fileprivate var wasPlaying = false
  
  let currentEpisode = AudioPlayer.shared.currentEpisode
  
  fileprivate let (volumeChangedSignal, volumeChangedObserver) = Signal<(), NoError>.pipe()
  fileprivate let (currentTimeChangedSignal, currentTimeChangedObserver) = Signal<(), NoError>.pipe()
  
  fileprivate var isVolumeSliderFocused = false {
    didSet {
      if isVolumeSliderFocused != oldValue {
          updateVolumeSliderBackground()
        
        if isVolumeSliderFocused {
          volumeChangedSignal.debounce(2.0, on: QueueScheduler.main).take(first: 1).observeValues { [weak self] _ in
            self?.isVolumeSliderFocused = false
          }
        }
      }
    }
  }
  
  private let tickDisposable = SerialDisposable()
  
  override func awake(withContext context: Any?) {
    super.awake(withContext: context)
    
    play()
    
    crownSequencer.delegate = self
    
    currentEpisode.producer.skip(first: 1).take(while: { $0 != nil }).startWithCompleted(pop)
    
    currentEpisode.producer.startWithValues { [weak self] episode in
      self?.updateBackground(image: episode?.artworkImage)
      
      self?.podcastTitleLabel.setText(episode?.podcast.title)
      self?.episodeTitleLabel.setText(episode?.title)
      
      self?.updateTimeLabels()
    }
    
    currentTimeChangedSignal.debounce(0.25, on: QueueScheduler.main).observeValues { [weak self] _ in
      if let _self = self, _self.wasPlaying {
        _self.wasPlaying = false
        _self.play()
      }
    }
    
    NotificationCenter.default.addObserver(forName: NSNotification.Name.AVAudioSessionRouteChange,
                                           object: nil,
                                           queue: OperationQueue.main) { [weak self] notification in
                                            guard let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                                              let reason = AVAudioSessionRouteChangeReason(rawValue: reasonValue) else {
                                              return
                                            }
                                            
                                            switch reason {
                                            case .newDeviceAvailable:
                                              self?.play()
                                              
                                            case .oldDeviceUnavailable:
                                              self?.pause()
                                              
                                            default:
                                              break
                                            }
    }
  }
  
  override func willActivate() {
    super.willActivate()
    
    crownSequencer.focus()
  }
  
  private func updateBackground(image: UIImage?) {
    guard let image = image else {
      containerGroup.setBackgroundImage(nil)
      return
    }
    
    UIGraphicsBeginImageContextWithOptions(contentFrame.size, true, 0.0)
    
    guard let context = UIGraphicsGetCurrentContext() else {
      return
    }
  
    let width = contentFrame.width
    let imageRect = CGRect(x: 0,
                           y: contentFrame.height-width,
                           width: width,
                           height: width)
    
    UIBezierPath(roundedRect: imageRect, cornerRadius: 6).addClip()
    image.draw(in: imageRect, blendMode: .normal, alpha: 0.15)
    let background = context.makeImage().map { UIImage(cgImage: $0) }
    UIGraphicsEndImageContext()
    
    containerGroup.setBackgroundImage(background)
  }
  
  private func updateVolumeSliderBackground() {
    if isVolumeSliderFocused == false {
        volumeSliderBackground.setBackgroundImage(nil)
        return
    }

    volumeSliderBackground.setBackgroundImage(UIImage(named: "Volume Border")!)
  }
  
  fileprivate func updateTimeLabels() {
    let player = AudioPlayer.shared
    
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .positional
    formatter.zeroFormattingBehavior = [ .pad ]
    
    let currentTime = player.currentTime
    
    if currentTime >= 60*60 {
      formatter.allowedUnits = [ .hour, .minute, .second ]
      
    } else {
      formatter.allowedUnits = [ .minute, .second ]
    }
    
    currentLabel.setText(formatter.string(from: currentTime))
    
    let remainingTime = player.duration-currentTime
    
    if remainingTime >= 60*60 {
      formatter.allowedUnits = [ .hour, .minute, .second ]
    } else {
      formatter.allowedUnits = [ .minute, .second ]
    }
    
    remainingLabel.setText(formatter.string(from: remainingTime).map({ "-\($0)" }))
    
    progressBar.setWidth(contentFrame.width*CGFloat(currentTime/player.duration))
  }
  
  fileprivate func updateRateLabel() {
    let rate = AudioPlayer.shared.rate
    
    if rate == 1.0 {
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
    if AudioPlayer.shared.isPlaying {
      pause()
    } else {
      play()
    }
  }
  
  fileprivate func pause() {
    WKInterfaceDevice.current().play(.click)
    
    tickDisposable.inner = nil
    AudioPlayer.shared.pause()
    
    playPauseButton.setBackgroundImage(UIImage(named: "Play"))
    
    updateTimeLabels()
  }
  
  private func play() {
    WKInterfaceDevice.current().play(.click)
    
    playPauseButton.setBackgroundImage(UIImage(named: "Pause"))
    
    let session = AVAudioSession.sharedInstance()
    try! session.setActive(true)
    try! session.setCategory(AVAudioSessionCategoryPlayback, with: .duckOthers)
    
    let player = AudioPlayer.shared
    player.play()
    
    let interval = DispatchTimeInterval.milliseconds(1000/Int(player.rate))
    tickDisposable.inner = timer(interval: interval, on: QueueScheduler.main).map({ _ in () }).startWithValues(updateTimeLabels)
  }
  
  @IBAction func handleBack() {
    WKInterfaceDevice.current().play(.click)
    
    AudioPlayer.shared.currentTime -= 15
    currentTimeChangedObserver.send(value: ())
  }
  
  
  @IBAction func handleForward() {
    WKInterfaceDevice.current().play(.click)
    
    AudioPlayer.shared.currentTime += 15
    currentTimeChangedObserver.send(value: ())
  }
  
  @IBAction func handleVolumePress(_ value: Float) {
    isVolumeSliderFocused = true
    
    WKInterfaceDevice.current().play(.click)
    
    AudioPlayer.shared.volume = value
    volumeChangedObserver.send(value: ())
  }
  
  @IBAction func handleSpeedDown() {
    WKInterfaceDevice.current().play(.directionDown)
    
    AudioPlayer.shared.rate -= 0.1
    updateRateLabel()
  }
  
  @IBAction func handleSpeedUp() {
    WKInterfaceDevice.current().play(.directionUp)
    
    AudioPlayer.shared.rate += 0.1
    updateRateLabel()
  }
  
  @IBAction func handleSeekTo() {
    WKInterfaceDevice.current().play(.success)
    
    pushController(withName: "SeekTo", context: nil)
  }
  
  @IBAction func handleDelete() {
    WKInterfaceDevice.current().play(.success)
    
    pause()
    
    guard let episode = currentEpisode.value else {
      return
    }
    
    PodcastTransferManager.shared.deletePodcast(episode)
    _ = AudioPlayer.shared.handleNextInQueue()
  }
  
  override func willDisappear() {
    super.willDisappear()
    
    currentEpisode.value?.startTime = AudioPlayer.shared.currentTime
    
    PersistentContainer.saveContext()
  }
}

extension NowPlayingController: WKCrownDelegate {
  func crownDidRotate(_ crownSequencer: WKCrownSequencer?, rotationalDelta: Double) {
    let player = AudioPlayer.shared
    
    if isVolumeSliderFocused {
      let volume = max(min(1.0, player.volume+Float(rotationalDelta)*2), 0.0)
      player.volume = volume
      volumeChangedObserver.send(value: ())
      volumeSlider.setValue(volume)
    } else {
      if player.isPlaying {
        wasPlaying = true
        pause()
      }
      
      let delta = rotationalDelta*20*pow(1+rotationalDelta, 4)
      
      //Check to prevent playback reset
      if player.currentTime + delta > player.duration-0.1 {
        player.currentTime = player.duration-0.1
      } else {
        player.currentTime += delta
      }

      currentTimeChangedObserver.send(value: ())
      
      updateTimeLabels()
    }
  }
}
