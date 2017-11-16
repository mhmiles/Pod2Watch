//
//  NotSecureController.swift
//  Pod2Watch WatchKit Extension
//
//  Created by Miles Hollingsworth on 11/15/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import WatchKit
import Foundation


class NotSecureController: WKInterfaceController {
  @IBOutlet var episodeTitleLabel: WKInterfaceLabel!
  
  @IBAction func handleDismiss() {
    dismiss()
  }
  
  override func awake(withContext context: Any?) {
    guard let userInfo = context as? [String: String] else { return }
    
    episodeTitleLabel.setText(userInfo["episodeTitle"])
  }
}

