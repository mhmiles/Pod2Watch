//
//  RequestNotificationController.swift
//  Pod2Watch WatchKit Extension
//
//  Created by Miles Hollingsworth on 11/15/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import WatchKit
import Foundation
import UserNotifications

class RequestNotificationController: WKInterfaceController {
  @IBAction func handleOK() {
    dismiss()
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound], completionHandler: { (success, error) in })
  }
}
