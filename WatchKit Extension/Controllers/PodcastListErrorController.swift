//
//  PodcastListErrorController.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 11/15/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import WatchKit

class PodcastListErrorController: WKInterfaceController {
  @IBAction func handleDismiss() {
    popToRootController()
  }
}
