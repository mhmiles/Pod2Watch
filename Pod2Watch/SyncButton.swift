
//
//  SyncButton.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 2/27/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import UIKit

enum SyncState: Int {
  case noSync = 0
  case preparing
  case pending
  case synced
}

class SyncButton: BorderButton {
  var syncState: SyncState? {
    didSet {
      switch syncState {
      case .noSync?:
        layer.borderWidth = 1.0
        setTitle("SYNC", for: .normal)
        
      case .preparing?:
        layer.borderWidth = 0.0
        setTitle("PREPARING", for: .normal)

      case .pending?:
        layer.borderWidth = 0.0
        setTitle("PENDING", for: .normal)
        
      case .synced?:
        layer.borderWidth = 0.0
        setTitle("SYNCED", for: .normal)
        
      case nil:
        layer.borderWidth = 0.0
        setTitle(nil, for: .normal)
      }
    }
  }
}
