//
//  BorderButton.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 2/11/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import UIKit

class BorderButton: UIButton {
  override func awakeFromNib() {
    super.awakeFromNib()

    layer.cornerRadius = 3.0
    layer.borderWidth = 1.0
    layer.borderColor = tintColor.cgColor
  }

  override func tintColorDidChange() {
    super.tintColorDidChange()

    layer.borderColor = tintColor.cgColor
  }
}
