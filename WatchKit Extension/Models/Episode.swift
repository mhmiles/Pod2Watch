//
//  Episode.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 4/3/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import WatchKit
import UIKit
import CoreData

public class Episode: NSManagedObject {
  @nonobjc public class func fetchRequest() -> NSFetchRequest<Episode> {
    return NSFetchRequest<Episode>(entityName: "Episode")
  }
  
  @NSManaged public var podcast: Podcast
  @NSManaged public var title: String?
  @NSManaged public var fileURL: URL
  @NSManaged public var playbackDuration: Double
  @NSManaged public var persistentID: Int64
  @NSManaged public var podcastTitle: String?
  @NSManaged public var sortIndex: Int16
  @NSManaged public var startTime: Double
  
  var artworkImage: UIImage? {
    return podcast.artworkImage
  }
  
  var isPlayed: Bool {
    return playbackDuration - startTime > 15
  }
}
