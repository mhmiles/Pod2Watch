//
//  String + SanitizeFilePath.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 5/6/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import Foundation

extension String {
  var forFileName: String {
    let characterSet = CharacterSet(charactersIn: " \"\\/?<>:*|")

    return components(separatedBy: characterSet).joined(separator: "_")
  }
}
