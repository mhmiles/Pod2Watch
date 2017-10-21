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

  private var selectedHours = 0
  private var selectedMinutes = 0
  private var selectedSeconds = 0

  private var selectedDuration: Double {
    return Double(selectedHours*3600 + selectedMinutes*60 + selectedSeconds)
  }
  
  private var didChangeSelection = false

  private var deallocDisposable: ScopedDisposable<AnyDisposable>?

  override func awake(withContext context: Any?) {
    super.awake(withContext: context)

    let disposable = AudioPlayer.shared.currentItem.producer.skip(first: 1).startWithValues { [unowned self] _ in
      self.pop()
    }
    
    deallocDisposable = ScopedDisposable(disposable)
    
    setRowContents()
    setSelectedDurations()
    setSelectedPickerRows()

  }

  private func setRowContents() {
    let playbackDuration = AudioPlayer.shared.duration.value
    let hoursMax = Int(playbackDuration/3600)
    let minutesMax = playbackDuration >= 3600 ? 59 : Int(playbackDuration/60)%60
    let secondsMax = playbackDuration >= 60 ? 59 : Int(playbackDuration)%60
    
    self.hourPicker.setItems((0...hoursMax).map({ number -> WKPickerItem in
      let item = WKPickerItem()
      item.title = String(number)
      item.caption = "h"
      
      return item
    }))
    
    self.minutePicker.setItems((0...minutesMax).map({ number -> WKPickerItem in
      let item = WKPickerItem()
      item.title = String(number)
      item.caption = "m"
      
      return item
    }))
    
    self.secondPicker.setItems((0...secondsMax).map({ number -> WKPickerItem in
      let item = WKPickerItem()
      item.title = String(number)
      item.caption = "s"
      
      return item
    }))
  }
  
  private func setSelectedDurations() {
    let currentTime = AudioPlayer.shared.offset.value
  
    selectedHours = Int(currentTime/3600)
    selectedMinutes = Int(currentTime/60)%60
    selectedSeconds = Int(currentTime)%60
  }

  private func setSelectedPickerRows() {
    hourPicker.setSelectedItemIndex(selectedHours)
    minutePicker.setSelectedItemIndex(selectedMinutes)
    secondPicker.setSelectedItemIndex(selectedSeconds)
  }

  @IBAction func handleHoursSelection(_ value: Int) {
    WKInterfaceDevice.current().play(.click)
    didChangeSelection = true
    selectedHours = value
  }

  @IBAction func handleMinutesSelection(_ value: Int) {
    WKInterfaceDevice.current().play(.click)
    didChangeSelection = true
    selectedMinutes = value
  }

  @IBAction func handleSecondsSelection(_ value: Int) {
    WKInterfaceDevice.current().play(.click)
    didChangeSelection = true
    selectedSeconds = value
  }

  @IBAction func handleOK() {
    WKInterfaceDevice.current().play(.success)

    if didChangeSelection {
      AudioPlayer.shared.setCurrentTime(selectedDuration)
    }
    
    pop()
  }
}
