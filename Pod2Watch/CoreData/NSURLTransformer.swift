//
//  URLTransformer.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 3/30/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import UIKit
import CoreData

@objc class NSURLTransformer: ValueTransformer {
  override class func transformedValueClass() -> Swift.AnyClass {
    return NSString.self
  }
  
  override func transformedValue(_ value: Any?) -> Any? {
    guard let url = value as? NSURL, let urlString = url.absoluteString else {
      return nil
    }
    
    return urlString as NSString
  }
  
  override class func allowsReverseTransformation() -> Bool {
    return true
  }
  
  override func reverseTransformedValue(_ value: Any?) -> Any? {
    guard let urlString = value as? String else {
      return nil
    }
    
    return NSURL(string: urlString)
  }
}
