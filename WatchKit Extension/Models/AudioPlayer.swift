//
//  AudioPlayer.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 5/5/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import Foundation
import ReactiveSwift
import enum Result.NoError
import WatchKit
import AVFoundation
import ReactiveCocoa

class AudioPlayer: NSObject {
  static let shared = AudioPlayer()
  
  var episodeQueue: [Episode]? {
    didSet {
      player?.removeAllItems()
      _currentItem.value = nil
      
      let playerItems = episodeQueue?.map { episode -> WKAudioFilePlayerItem in
        let asset = WKAudioFileAsset(url: episode.fileURL!)
        let item = WKAudioFilePlayerItem(asset: asset)
        item.setCurrentTime(episode.startTime)
        
        return item
      }
      
      player = playerItems.map { WKAudioFileQueuePlayer(items: $0) }
      
      updateCurrentItem()
      updatePlayheadPosition()
    }
  }
  
  @objc fileprivate var player: WKAudioFileQueuePlayer?
  
  private var deallocDisposable: ScopedDisposable<AnyDisposable>?
  
  let isPlayingProperty: Property<Bool>
  private let _isPlaying = MutableProperty(false)
  
  var isPlaying: Bool {
    return (self.player?.rate ?? 0) > 0
  }
  
  let currentItem: Property<WKAudioFilePlayerItem?>
  private let _currentItem: MutableProperty<WKAudioFilePlayerItem?> = MutableProperty(nil)
  
  var currentEpisode: Episode? {
    guard let currentItemURL = player?.currentItem?.asset.url else {
      return nil
    }
    
    return episodeQueue?.first(where: { (episode) -> Bool in
      return episode.fileURL == currentItemURL
    })
  }
  
  private let tickDisposable = SerialDisposable()
  
  let offset: Property<TimeInterval>
  private let _offset: MutableProperty<TimeInterval> = MutableProperty(0)
  
  let duration: Property<TimeInterval>
  private let _duration: MutableProperty<TimeInterval> = MutableProperty(0)
  
  private let rateTickDisposable = SerialDisposable()
  
  var rate: Float {
    get {
      return player?.rate ?? 0
    } set {
      player?.rate = newValue
      
      configureRateTimer()
    }
  }
  
  override init() {
    isPlayingProperty = Property(_isPlaying)
    offset = Property(_offset.map({ $0.isNaN ? 0 : $0 }))
    duration = Property(_duration)
    
    currentItem = Property(initial: nil, then: _currentItem.producer.skipRepeats({ (previous, current) in
      if previous == current {
        return true
      }
      
      guard let previous = previous, let current = current else {
        return false
      }
      
      return previous.asset.url == current.asset.url
    }))
    
    super.init()
    
    configureUpdateTimer()
    configureRateTimer()
  }
  
  private func configureUpdateTimer() {
    let compositeDisposable = CompositeDisposable()
    
    compositeDisposable += SignalProducer.timer(interval: .seconds(2),
                                                on: QueueScheduler.main).startWithValues { [unowned self ] _ in
                                                  self.updateCurrentItem()
    }
    
    compositeDisposable += SignalProducer.timer(interval: .seconds(1),
                                                on: QueueScheduler.main).startWithValues({ [unowned self] _ in
                                                  self.updateIsPlaying()
                                                })
    
    tickDisposable.inner = compositeDisposable
  }
  
  private func updateIsPlaying() {
    _isPlaying.value = isPlaying
  }
  
  private func configureRateTimer(){
    let adjustedInterval = DispatchTimeInterval.milliseconds(1000000/Int((rate == 0 ? 1 : rate)*1000))
    
     rateTickDisposable.inner = SignalProducer.timer(interval: adjustedInterval, on: QueueScheduler.main).startWithValues { [unowned self ] _ in
      self.updatePlayheadPosition()
    }
  }
  
  private func updatePlayheadPosition() {
    _offset.value = currentItem.value?.currentTime ?? 0
    _duration.value = currentItem.value?.asset.duration ?? 0
  }
  
  private func updateCurrentItem() {
    _currentItem.value = player?.currentItem
  }
  
  func play() {
//    let audioSession = AVAudioSession.sharedInstance()
//
//    do {
//      try audioSession.setCategory(AVAudioSessionCategoryPlayback,
//                                   with: [.allowBluetoothA2DP, .duckOthers])
//      print(try audioSession.setActive(true))
//    } catch let error {
//      print(error)
//    }
    
    guard let player = player, isPlaying == false else {
      return
    }
    
    player.play()
    updateIsPlaying()
  }
  
  func pause() {
    player?.pause()
    updateIsPlaying()
    updatePlayheadPosition()
    
    updateStartTime()
  }
  
  func playPause() {
    if isPlaying {
      pause()
    } else {
      play()
    }
  }
  
  func setCurrentTime(_ currentTime: TimeInterval) {
    guard let currentItem = player?.currentItem else {
      return
    }
    
    currentItem.setCurrentTime(currentTime < 0 ? 0 : currentTime)
    updatePlayheadPosition()
    
    updateStartTime()
  }
  
  func advance(_ distance: TimeInterval) {
    guard let currentItem = player?.currentItem else {
      return
    }
    
    setCurrentTime(currentItem.currentTime+distance)
  }
  
  func advanceToNextItem() {
    player?.advanceToNextItem()
    
    updateStartTime()
  }
  
  func updateStartTime() {
    if let episode = currentEpisode {
      episode.startTime = offset.value
      
      PersistentContainer.saveContext()
    }
  }
  
  func removeFromQueue(episodes: [Episode]) {
    guard let episodeQueue = episodeQueue, episodeQueue.count > 0 else {
      return
    }
  
    self.episodeQueue = episodeQueue.filter { episodes.contains($0) == false }
  }

}
