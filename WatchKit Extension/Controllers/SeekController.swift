//
//  SeekController.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 5/6/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import WatchKit
import Foundation
import ReactiveSwift

class SeekController: WKInterfaceController {

  @IBOutlet var hourPicker: WKInterfacePicker!
  @IBOutlet var minutePicker: WKInterfacePicker!
  @IBOutlet var secondPicker: WKInterfacePicker!
  
  var selectedHours = 0
  var selectedMinutes = 0
  var selectedSeconds = 0
  
  var selectedStartTime: Double {
    return Double(selectedHours*3600 + selectedMinutes*60 + selectedSeconds)
  }
  
  var currentEpisodeDisposable: Disposable?
  
  override func awake(withContext context: Any?) {
    super.awake(withContext: context)
    
    currentEpisodeDisposable = AudioPlayer.shared.currentEpisode.producer.startWithValues { [weak self] episode in
      guard let episode = episode else {
        return
      }
      
      let playbackDuration = episode.playbackDuration
      let hoursMax = Int(playbackDuration/3600)
      let minutesMax = playbackDuration >= 3600 ? 59 : Int(playbackDuration/60)%60
      let secondsMax = playbackDuration >= 60 ? 59 : Int(playbackDuration)%60
      
      self?.hourPicker.setItems((0...hoursMax).map({ number -> WKPickerItem in
        let item = WKPickerItem()
        item.title = String(number)
        item.caption = "h"
        
        return item
      }))
      
      self?.minutePicker.setItems((0...minutesMax).map({ number -> WKPickerItem in
        let item = WKPickerItem()
        item.title = String(number)
        item.caption = "m"
        
        return item
      }))
      
      self?.secondPicker.setItems((0...secondsMax).map({ number -> WKPickerItem in
        let item = WKPickerItem()
        item.title = String(number)
        item.caption = "s"
        
        return item
      }))
      
      self?.setSelectedDurations(episode)
      self?.setPickerRows()
    }
  }
  
  private func setSelectedDurations(_ episode: Episode) {
    selectedHours = Int(episode.startTime/3600)
    selectedMinutes = Int(episode.startTime/60)%60
    selectedSeconds = Int(episode.startTime)%60
  }
  
  private func setPickerRows() {
    hourPicker.setSelectedItemIndex(selectedHours)
    minutePicker.setSelectedItemIndex(selectedMinutes)
    secondPicker.setSelectedItemIndex(selectedSeconds)
  }
  
  @IBAction func handleHoursSelection(_ value: Int) {
    WKInterfaceDevice.current().play(.click)
    selectedHours = value
  }
  
  @IBAction func handleMinutesSelection(_ value: Int) {
    WKInterfaceDevice.current().play(.click)
    selectedMinutes = value
  }
  
  @IBAction func handleSecondsSelection(_ value: Int) {
    WKInterfaceDevice.current().play(.click)
    selectedSeconds = value
  }
  
  @IBAction func handleOK() {
    WKInterfaceDevice.current().play(.success)

    AudioPlayer.shared.currentTime = selectedStartTime
    pop()
  }
  
  override func willDisappear() {
    currentEpisodeDisposable?.dispose()
  }
}
