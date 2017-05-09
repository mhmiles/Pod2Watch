//
//  MessageType.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 4/2/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import Foundation

struct MessageType {
  static let requestPending = "requestPending"
  static let requestDeletes = "requestDeletes"
  static let requestArtwork = "requestArtwork"
  static let sendEpisode = "sendEpisode"
  static let sendDeletes = "sendDeletes"
  static let sendArtwork = "sendArtwork"
  static let confirmDeletes = "confirmDeletes"
  static let sendDeleteAll = "sendDeleteAll"
  static let confirmDeleteAll = "confirmDeleteAll"
  static let requestUsedStorage = "requestUsedStorage"
  static let sendUsedStorage = "sendUsedStorage"
}
