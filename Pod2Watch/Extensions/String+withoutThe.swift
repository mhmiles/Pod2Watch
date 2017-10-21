//
//  String+withoutThe.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 3/26/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import Foundation

extension String {
  var withoutThe: String {
    if lowercased().hasPrefix("the ") {
      return self["the ".endIndex...].trimmingCharacters(in: CharacterSet.whitespaces)
    } else {
      return self
    }
  }
}
