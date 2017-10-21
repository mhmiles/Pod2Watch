//
//  BorderButton.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 2/11/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import UIKit

extension String {
  static let borderColor = "borderColor"
}

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
  
  override var isHighlighted: Bool {
    didSet {
      if oldValue == isHighlighted {
        return
      }
      
      if isHighlighted {
        layer.borderColor = tintColor.withAlphaComponent(0.21).cgColor
        layer.removeAnimation(forKey: .borderColor)
      } else {
        let animation = CABasicAnimation(keyPath: #keyPath(CALayer.borderColor))
        animation.fromValue = layer.presentation()?.borderColor
        animation.toValue = tintColor.cgColor
        animation.duration = 0.6
        animation.fillMode = kCAFillModeForwards
        animation.isRemovedOnCompletion = false
        
        layer.add(animation, forKey: .borderColor)
      }
    }
  }
}
