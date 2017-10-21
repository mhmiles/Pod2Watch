//
//  PodcastSectionController
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 2/14/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import UIKit
import IGListKit
import Alamofire
import AlamofireImage
import racAdditions
import ReactiveSwift

class PodcastSectionController: ListSectionController {
  var viewModel: PodcastCellViewModel!
  let imageDisposable = SerialDisposable()
  
  override init() {
    super.init()
    
    minimumInteritemSpacing = 3
    inset = UIEdgeInsets(top: 0, left: 0, bottom: 3, right: 0)
  }
  
  override func sizeForItem(at index: Int) -> CGSize {
    guard let totalWidth = collectionContext?.containerSize.width else { fatalError() }
    
    let width = (totalWidth-minimumInteritemSpacing)/2
    return CGSize(width: width, height: width)
  }
  
  override func cellForItem(at index: Int) -> UICollectionViewCell {
    guard let cell = collectionContext?.dequeueReusableCellFromStoryboard(withIdentifier: "PodcastCell",
                                                                          for: self,
                                                                          at: index) as? PodcastCell else {
                                                                            fatalError()
    }
    
    imageDisposable.inner = cell.imageView.rac_image <~ viewModel.artworkProducer
    
    return cell
  }
  
  override func didUpdate(to object: Any) {
    guard let viewModel = object as? PodcastCellViewModel else {
      fatalError()
    }
    
    self.viewModel = viewModel
  }
}

