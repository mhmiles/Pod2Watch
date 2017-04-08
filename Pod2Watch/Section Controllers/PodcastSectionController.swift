//
//  PodcastSectionController.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 2/14/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import UIKit
import IGListKit
import MediaPlayer.MPMediaItemCollection
import Alamofire
import AlamofireImage
import racAdditions
import ReactiveSwift

class PodcastSectionController: IGListSectionController, IGListSectionType {
  var podcast: LibraryPodcastEpisode?
  
  func numberOfItems() -> Int {
    return 1
  }
  
  func sizeForItem(at index: Int) -> CGSize {
    let width = collectionContext!.containerSize.width/2 - 1
    return CGSize(width: width, height: width)
  }
  
  func cellForItem(at index: Int) -> UICollectionViewCell {
    let cell = collectionContext!.dequeueReusableCellFromStoryboard(withIdentifier: "PodcastCell",
                                                                            for: self, at: index) as! PodcastCell
    guard let podcast = podcast else {
      return cell
    }
    
    cell.imageView.rac_image <~ podcast.podcastArtworkProducer
    
    return cell
  }
  
  func didUpdate(to object: Any) {
    podcast = object as? LibraryPodcastEpisode
  }
  
  func didSelectItem(at index: Int) {
    
  }
}
