//
//  ExtensionDelegate.swift
//  Pod2Watch WatchKit Extension
//
//  Created by Miles Hollingsworth on 2/8/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import WatchKit
import WatchConnectivity

class ExtensionDelegate: NSObject, WKExtensionDelegate {
  func applicationDidBecomeActive() {
    let _ = PodcastDownloadManager.shared
  }
  
  func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
    for task in backgroundTasks {
      // Use a switch statement to check the task type
      switch task {
        
      case let snapshotTask as WKSnapshotRefreshBackgroundTask:
        snapshotTask.setTaskCompleted(restoredDefaultState: false,
                                      estimatedSnapshotExpiration: Date().addingTimeInterval(60 * 60),
                                      userInfo: nil)
        
      case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
        let _ = PodcastDownloadManager.shared
        connectivityTask.setTaskCompletedWithSnapshot(true)
        
      case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
       PodcastDownloadManager.shared.backgrounndRefreshTask = urlSessionTask
        
      default:
        task.setTaskCompletedWithSnapshot(false)
      }
    }
  }
}
