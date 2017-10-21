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

class OpenPodcastsSectionController: ListSectionController {
  weak var delegate: OpenPodcastsSectionControllerDelegate?
  
  override func sizeForItem(at index: Int) -> CGSize {
    guard let width = collectionContext?.containerSize.width else { fatalError() }

    return CGSize(width: width, height: 120)
  }
  
  override func cellForItem(at index: Int) -> UICollectionViewCell {
    guard let cell = collectionContext?.dequeueReusableCellFromStoryboard(withIdentifier: "OpenPodcastsCell",
                                                                          for: self,
                                                                          at: index) as? OpenPodcastsCell else {
                                                                            fatalError()
    }
    
    cell.button.addTarget(self, action: #selector(handleButtonPress), for: .touchUpInside)
    
    return cell
  }
  
  @objc func handleButtonPress() {
    delegate?.handleOpenPodcasts()
  }
}

protocol OpenPodcastsSectionControllerDelegate: class {
  func handleOpenPodcasts()
}
