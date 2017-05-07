//
//  Podcast.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 5/6/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import UIKit
import CoreData

public class Podcast: NSManagedObject {
  @nonobjc public class func fetchRequest() -> NSFetchRequest<Podcast> {
    return NSFetchRequest<Podcast>(entityName: "Podcast")
  }
  
  @NSManaged public var title: String
  @NSManaged public var episodes: NSSet
  @NSManaged public var artworkImage: UIImage?
  
  convenience init(title: String, context: NSManagedObjectContext) {
    let entity = NSEntityDescription.entity(forEntityName: "Podcast", in: context)!
    self.init(entity: entity, insertInto: context)
    
    self.title = title
  }
}

// MARK: Generated accessors for episodes
extension Podcast {
  
  @objc(addEpisodesObject:)
  @NSManaged public func addToEpisodes(_ value: Episode)
  
  @objc(removeEpisodesObject:)
  @NSManaged public func removeFromEpisodes(_ value: Episode)
  
  @objc(addEpisodes:)
  @NSManaged public func addToEpisodes(_ values: NSSet)
  
  @objc(removeEpisodes:)
  @NSManaged public func removeFromEpisodes(_ values: NSSet)
  
}
