//
//  RootViewController.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 11/15/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import UIKit
import UserNotifications

class RootViewController: UITabBarController {
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(RootViewController.handleReceivedAuthorizationNotDetermined),
                                           name: .podcastTransferDidBegin,
                                           object: nil)
    
    UINavigationBar.appearance().shadowImage = UIImage()
  }
  
  @objc private func handleReceivedAuthorizationNotDetermined() {
    let center = UNUserNotificationCenter.current()
    center.getNotificationSettings(completionHandler: { (settings) in
      switch settings.authorizationStatus {
      case .notDetermined:
        let alertController = UIAlertController(title: "Download Notifications",
                                                message: "Would you like Pod2Watch to notify you when your downloads complete?",
                                                preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: "Yes",
                                                style: .cancel,
                                                handler: { (_) in
                                                  UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound],
                                                                                                          completionHandler: { (success, error) in
                                                  })
                                                  
                                                  alertController.addAction(UIAlertAction(title: "No",
                                                                                          style: .default,
                                                                                          handler: nil))
        }))
        
        self.present(alertController,
                     animated: true,
                     completion: nil)
        
      default:
        break
      }
    })
  }
}
