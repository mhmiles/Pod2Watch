//
//  UIApplication+OpenPodcasts.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 10/18/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import UIKit
import StoreKit

extension UIApplication {
  func openPodcasts() {
    let podcastsURL = URL(string: "pcast://")!
    
    if canOpenURL(podcastsURL) {
      UIApplication.shared.open(podcastsURL)
    } else {
      let rootViewController = keyWindow?.rootViewController
      let alertController = UIAlertController(title: "Install Podcasts App",
                                              message: "Pod2Watch shares a media library with the Apple Podcasts app\n\nWould you like to download it now?",
                                              preferredStyle: .alert)
      
      alertController.addAction(UIAlertAction(title: "Yes",
                                              style: .cancel,
                                              handler: { _ in
        let productViewController = SKStoreProductViewController()
        productViewController.delegate = self
                                                
        rootViewController?.present(productViewController,
                                               animated: true,
                                               completion: nil)
        
        productViewController.loadProduct(withParameters: [SKStoreProductParameterITunesItemIdentifier: "525463029"]) { (success, error) in
          if let error = error {
            print(error)
          }
        }
      }))
      
      alertController.addAction(UIAlertAction(title: "No",
                                              style: .default,
                                              handler: nil))
      
      rootViewController?.present(alertController, animated: true, completion: nil)
    }
  }
}

extension UIApplication: SKStoreProductViewControllerDelegate {
  public func productViewControllerDidFinish(_ viewController: SKStoreProductViewController) {
    keyWindow?.rootViewController?.dismiss(animated: true, completion: nil)
  }
}
