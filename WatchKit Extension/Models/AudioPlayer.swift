//
//  AudioPlayer.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 5/5/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import Foundation
import AVFoundation
import ReactiveSwift
import enum Result.NoError

class AudioPlayer: NSObject {
  static let shared = AudioPlayer()
  
  fileprivate let _currentEpisode = MutableProperty<Episode?>(nil)
  
  lazy var currentEpisode: Property<Episode?> = {
    return Property(self._currentEpisode)
  }()
  
  fileprivate var episodeQueue: [Episode]!
  
  fileprivate var player: AVAudioPlayer? {
    didSet {
      player?.enableRate = true
      player?.delegate = self
      player?.volume = volume
    }
  }
  
  var isPlaying: Bool {
    return player?.isPlaying ?? false
  }
  
  var volume: Float = 0.5 {
    didSet {
      player?.setVolume(exp(6.908*volume)/1000, fadeDuration: 0.1)
    }
  }
  
  var currentTime: TimeInterval {
    get {
      return player?.currentTime ?? 0
    }
    set {
      if newValue >= duration {
        pause()
        player?.currentTime = duration
        _currentEpisode.value?.startTime = duration
        handleNextInQueue()
      } else {
        player?.currentTime = newValue
      }
    }
  }
  
  var duration: TimeInterval {
    return _currentEpisode.value?.playbackDuration ?? 0
  }
  
  var rate: Float {
    get {
      return player?.rate ?? 1
    } set {
      player?.rate = newValue
    }
  }
  
  override init() {
    super.init()
    
    _currentEpisode.producer.startWithValues { [unowned self] episode in
      if let episode = episode {
        self.player = self.playerForFile(url: episode.fileURL)
      } else {
        self.player = nil
      }
      
      self.player?.currentTime = episode?.startTime ?? 0
    }
  }
  
  private func playerForFile(url: URL) -> AVAudioPlayer? {
    if let player = try? AVAudioPlayer(contentsOf: url) {
      return player
    }
    
    let mp3URL = url.deletingPathExtension().appendingPathExtension("mp3")
    try? FileManager.default.createSymbolicLink(at: mp3URL, withDestinationURL: url)
    
    if let player = try? AVAudioPlayer(contentsOf: mp3URL) {
      return player
    }
    
    let m4aURL = url.deletingPathExtension().appendingPathExtension("m4a")
    try? FileManager.default.createSymbolicLink(at: m4aURL, withDestinationURL: url)
    return try? AVAudioPlayer(contentsOf: m4aURL)
  }
  
  func queueEpisodes(_ episodes: [Episode]) {
    if let currentEpisode = _currentEpisode.value {
      currentEpisode.startTime = currentTime
    }
    
    episodeQueue = episodes
    
    if let episode = episodeQueue.first,
      episode == _currentEpisode.value {
      episodeQueue.removeFirst()
    } else {
      handleNextInQueue()
    }
  }
  
  func play() {
    player?.play()
  }
  
  func pause() {
    player?.pause()
  }
  
  func handleNextInQueue() {
    guard let nextEpisode = episodeQueue.first else {
      _currentEpisode.value = nil
      
      return
    }
    
    episodeQueue.removeFirst()
    _currentEpisode.value = nextEpisode
    play()
  }
}

extension AudioPlayer: AVAudioPlayerDelegate {
  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    if flag, let episode = _currentEpisode.value {
      episode.startTime = episode.playbackDuration
    }
    
    handleNextInQueue()
  }
}
