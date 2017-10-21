//
//  WKAudioFileQueuePlayer+RemoveCurrent.swift
//  Pod2Watch WatchKit Extension
//
//  Created by Miles Hollingsworth on 10/17/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import Foundation
import WatchKit

extension WKAudioFileQueuePlayer {
  func removeCurrentItem() {
    if let currentItem = currentItem{
      removeItem(currentItem)
    }
  }
}
