//
//  DownloadNotificationController.swift
//  Pod2Watch WatchKit Extension
//
//  Created by Miles Hollingsworth on 10/22/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import WatchKit
import Foundation
import UserNotifications

class DownloadNotificationController: WKUserNotificationInterfaceController {
  override func didReceive(_ notification: UNNotification, withCompletion completionHandler: @escaping (WKUserNotificationInterfaceType) -> Void) {
    print(notification.request.content)
  }
}
