//
//  PodcastCellViewModel.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 10/20/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import Foundation
import IGListKit
import ReactiveSwift
import enum Result.NoError

class PodcastCellViewModel: ListDiffable {
  func diffIdentifier() -> NSObjectProtocol {
    return title as NSString
  }
  
  func isEqual(toDiffableObject object: ListDiffable?) -> Bool {
    guard let viewModel = object as? PodcastCellViewModel else {
      return false
    }
    
    return viewModel.title == title
  }
  
  let title: String
  let artworkProducer: SignalProducer<UIImage?, NoError>
  
  init(title: String, artworkProducer: SignalProducer<UIImage?, NoError>) {
    self.title = title
    self.artworkProducer = artworkProducer
  }
}
