//
//  TransferredPodcast.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 4/21/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import UIKit
import CoreData

public class TransferredPodcast: NSManagedObject {
  @nonobjc public class func fetchRequest() -> NSFetchRequest<TransferredPodcast> {
    return NSFetchRequest<TransferredPodcast>(entityName: "TransferredPodcast")
  }
  
  @NSManaged public var artworkImage: UIImage?
  @NSManaged public var isAutoTransferred: Bool
  @NSManaged public var title: String?
  @NSManaged public var episodes: NSSet?

  convenience init(_ podcast: LibraryPodcast, context: NSManagedObjectContext) {
    let entity = NSEntityDescription.entity(forEntityName: "TransferredPodcast", in: context)!
    self.init(entity: entity, insertInto: context)
    
    title = podcast.title
    artworkImage = podcast.artworkImage
  }
}

// MARK: Generated accessors for episodes
extension TransferredPodcast {
  
  @objc(addEpisodesObject:)
  @NSManaged public func addToEpisodes(_ value: TransferredEpisode)
  
  @objc(removeEpisodesObject:)
  @NSManaged public func removeFromEpisodes(_ value: TransferredEpisode)
  
  @objc(addEpisodes:)
  @NSManaged public func addToEpisodes(_ values: NSSet)
  
  @objc(removeEpisodes:)
  @NSManaged public func removeFromEpisodes(_ values: NSSet)
  
}
