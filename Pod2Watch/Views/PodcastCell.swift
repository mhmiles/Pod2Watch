//
//  PodcastCell.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 2/10/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import UIKit

class PodcastCell: UICollectionViewCell {
  @IBOutlet weak var imageView: UIImageView!

  override func prepareForReuse() {
    super.prepareForReuse()

    imageView.image = nil
  }
}
