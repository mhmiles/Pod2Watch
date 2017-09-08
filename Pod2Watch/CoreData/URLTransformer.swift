//
//  URLTransformer.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 3/30/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import UIKit
import CoreData

@objc class URLTransformer: ValueTransformer {
  override class func transformedValueClass() -> Swift.AnyClass {
    return NSData.self
  }

  override func transformedValue(_ value: Any?) -> Any? {
    guard let url = value as? URL else {
      return nil
    }

    return url.absoluteString.data(using: .utf8)
  }

  override class func allowsReverseTransformation() -> Bool {
    return true
  }

  override func reverseTransformedValue(_ value: Any?) -> Any? {
    guard let data = value as? Data,
      let urlString = String(data: data, encoding: .utf8) else {
        return nil
    }

    return URL(string: urlString)
  }
}
