//
//  UIImageTransformer.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 5/4/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import UIKit
import CoreData

@objc class UIImageTransformer: ValueTransformer {
  override class func transformedValueClass() -> Swift.AnyClass {
    return NSData.self
  }

  override func transformedValue(_ value: Any?) -> Any? {
    guard let image = value as? UIImage else {
      return nil
    }

    return UIImageJPEGRepresentation(image, 1.0)
  }

  override class func allowsReverseTransformation() -> Bool {
    return true
  }

  override func reverseTransformedValue(_ value: Any?) -> Any? {
    guard let imageData = value as? Data else {
      return nil
    }

    return UIImage(data: imageData)
  }
}
