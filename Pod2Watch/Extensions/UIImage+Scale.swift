//
//  UIImage+Scale.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 5/6/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import UIKit

extension UIImage {
  func shrunkTo(size maxSize: CGSize) -> UIImage {
    let scale = min(maxSize.width/size.width, maxSize.height/size.height)
    
    if scale >= 1 {
      return self
    }
    
    let newSize = CGSize(width: size.width*scale, height: size.height*scale)
    
    UIGraphicsBeginImageContext(newSize)
    draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
    
    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    return image ?? self
  }
}
