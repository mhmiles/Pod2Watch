//
//  TransferredPodcast.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 4/21/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import Foundation
import CoreData

extension TransferredPodcast {
  convenience init(_ podcast: LibraryPodcast, context: NSManagedObjectContext) {
    self.init(context: context)
    
    title = podcast.title
    persistentID = podcast.persistentID
  }
}
