//
//  PodcastAlertController.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 10/20/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import UIKit

class PodcastAlertController: UIAlertController {
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setTintColor()
  }
  
  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    
    setTintColor()
  }
  
  private func setTintColor() {
    view.tintColor = UIColor(red:0.40, green:0.19, blue:0.83, alpha:1.0)
  }
}
