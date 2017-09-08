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
import ReactiveCocoa

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

  lazy var artworkImage: DynamicProperty<UIImage> = DynamicProperty(object: self,
                                                                    keyPath: #keyPath(Episode.podcast.artworkImage))

  var isPlayed: Bool {
    return playbackDuration - startTime > 15
  }

  class func existing(persistentIDs: [Int64]) -> [Episode] {
    let request: NSFetchRequest<Episode> = fetchRequest()
    request.predicate = NSPredicate(format: "persistentID IN %@", persistentIDs)

    return try! PersistentContainer.shared.viewContext.fetch(request)
  }

  class func all() -> [Episode] {
    let request: NSFetchRequest<Episode> = Episode.fetchRequest()
    return try! PersistentContainer.shared.viewContext.fetch(request)
  }
}
