//
//  BorderImageView.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 3/27/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import UIKit

class BorderImageView: UIImageView {
  override func awakeFromNib() {
    super.awakeFromNib()

    layer.borderColor = UIColor(white: 0.8, alpha: 1.0).cgColor
    layer.cornerRadius = 3
    layer.masksToBounds = true
  }
}
