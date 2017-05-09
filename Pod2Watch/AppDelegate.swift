//
//  AppDelegate.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 2/8/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import UIKit
import MediaPlayer

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    _ = PodcastTransferManager.shared
  
    return true
  }
  
  func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    if PodcastTransferManager.shared.handleAutoTransfers() {
      completionHandler(.newData)
    } else {
      completionHandler(.noData)
    }
  }
}
