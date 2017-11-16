//
//  MHReviewRequester.swift
//  Master Control
//
//  Created by Miles Hollingsworth on 11/4/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import StoreKit

private extension String {
  static let launchCount = "LaunchCount"
}

public class ReviewRequester {
  public static let shared = ReviewRequester()
  
  init() {
    NotificationCenter.default.addObserver(forName: Notification.Name.UIApplicationDidBecomeActive,
                                           object: nil,
                                           queue: nil) { (_) in
                                            self.incrementLaunchCount()
    }
  }
  
  private func incrementLaunchCount() {
    let defaults = UserDefaults.standard
    let launchCount = defaults.integer(forKey: .launchCount)+1
    
    defaults.set(launchCount,
                 forKey: .launchCount)
    defaults.synchronize()
    
    guard launchCount > 5 else {
      if launchCount == 5 {
        SKStoreReviewController.requestReview()
      }
      
      return
    }
    
    
    let weekOfYearComponents = Calendar.current.dateComponents([.weekOfYear], from: Date())
    
    guard let weekOfYear = weekOfYearComponents.weekOfYear else {
      return
    }
    
    // Request a review every 13 weeks
    if (weekOfYear + UIDevice.current.name.hashValue) % 13 == 0 {
      SKStoreReviewController.requestReview()
    }
  }
}
