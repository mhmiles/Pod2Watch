//
//  MPMediaItemCollection+IGListDiffable.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 3/25/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import Foundation
import IGListKit
import MediaPlayer

extension MPMediaItemCollection: IGListDiffable {
  public func diffIdentifier() -> NSObjectProtocol {
    return representativeItem!.podcastTitle! as NSObjectProtocol
  }
  
  public func isEqual(toDiffableObject object: IGListDiffable?) -> Bool {
    guard let podcast = object as? MPMediaItemCollection else {
      return false
    }
    
    return podcast.representativeItem?.podcastTitle ?? "" == representativeItem?.podcastTitle ?? ""
  }
}
