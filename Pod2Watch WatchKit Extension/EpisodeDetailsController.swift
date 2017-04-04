//
//  EpisodeDetailsController.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 4/2/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import WatchKit

class EpisodeDetailsController: WKInterfaceController {
  
  var episode: PodcastEpisode!
  
  @IBOutlet weak var playButton: WKInterfaceButton!
  
  @IBOutlet var podcastTitleLabel: WKInterfaceLabel!
  @IBOutlet var episodeTitleLabel: WKInterfaceLabel!
  
  @IBOutlet weak var hourPicker: WKInterfacePicker!
  @IBOutlet weak var minutePicker: WKInterfacePicker!
  @IBOutlet weak var secondPicker: WKInterfacePicker!
  
  var selectedHours = 0
  var selectedMinutes = 0
  var selectedSeconds = 0
  
  var selectedStartTime: Double {
    return Double(selectedHours*3600 + selectedMinutes*60 + selectedSeconds)
  }
  
  override func awake(withContext context: Any?) {
    guard let episode = context as? PodcastEpisode else {
      fatalError("No episode passed")
    }
    
    self.episode = episode

    podcastTitleLabel.setText(episode.podcastTitle)
    episodeTitleLabel.setText(episode.episodeTitle)
    
    let playbackDuration = episode.playbackDuration
    
    let hoursMax = Int(playbackDuration/3600)
    let minutesMax = playbackDuration >= 3600 ? 59 : Int(playbackDuration/60)%60
    let secondsMax = playbackDuration >= 60 ? 59 : Int(playbackDuration)%60
    
    hourPicker.setItems((0...hoursMax).map({ number -> WKPickerItem in
      let item = WKPickerItem()
      item.title = String(number)
      item.caption = "h"
      
      return item
    }))
    
    minutePicker.setItems((0...minutesMax).map({ number -> WKPickerItem in
      let item = WKPickerItem()
      item.title = String(number)
      item.caption = "m"
      
      return item
    }))
    
    secondPicker.setItems((0...secondsMax).map({ number -> WKPickerItem in
      let item = WKPickerItem()
      item.title = String(number)
      item.caption = "s"
      
      return item
    }))
    
    setSelectedDurations()
    setPickerRows()
  }
  
  private func setSelectedDurations() {
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
    selectedHours = value
  }
  
  @IBAction func handleMinutesSelection(_ value: Int) {
    selectedMinutes = value
  }
  
  @IBAction func handleSecondsSelection(_ value: Int) {
    selectedSeconds = value
  }
  
  @IBAction func handlePlay() {
    let options = [WKMediaPlayerControllerOptionsStartTimeKey: NSNumber(value: selectedStartTime)]
    presentMediaPlayerController(with: episode.fileURL,
                                 options: options) { [unowned self] (finished, endTime, error) in
      if let error = error {
        print(error.localizedDescription)
      }
      
      if finished {
        self.episode.startTime = 0
      } else {
        self.episode.startTime = endTime
      }
      
      self.setSelectedDurations()
      self.setPickerRows()
      
      PersistentContainer.saveContext()
    }
  }
}
