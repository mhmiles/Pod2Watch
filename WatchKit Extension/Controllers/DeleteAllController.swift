//
//  DeleteAllController.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 10/21/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import WatchKit
import Foundation

class DeleteAllController: WKInterfaceController {

  @IBAction func handleConfirmDeleteAll() {
    PodcastTransferManager.shared.deleteAllPodcasts()
    WKInterfaceDevice.current().play(.success)
    dismiss()
  }
}
