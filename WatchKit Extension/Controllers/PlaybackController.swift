//
//  PlaybackController.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 4/8/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import WatchKit
import Foundation
import AVFoundation


class PlaybackController: WKInterfaceController {
  var audioPlayer: AVAudioPlayer!
  
  override func awake(withContext context: Any?) {
    super.awake(withContext: context)

    // Configure interface objects here.
    
    guard let audioFileURL = context as? URL else {
      return
    }
    
    do {
      try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, with: .allowBluetoothA2DP)
      try AVAudioSession.sharedInstance().setActive(true)
      audioPlayer = try AVAudioPlayer(contentsOf: audioFileURL, fileTypeHint: "public.mp3")
      audioPlayer.play()
    } catch let error {
      print(error)
    }

  }
  
  override func willActivate() {
    // This method is called when watch view controller is about to be visible to user
    super.willActivate()
  }
  
  override func didDeactivate() {
    // This method is called when watch view controller is no longer visible
    super.didDeactivate()
  }
  
}
