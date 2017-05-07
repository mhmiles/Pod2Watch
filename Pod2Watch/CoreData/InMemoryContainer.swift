//
//  InMemoryContainer.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 3/26/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import Foundation
import CoreData
import MediaPlayer
import NotificationCenter

public final class InMemoryContainer: NSPersistentContainer {
  public static var applicationGroupIdentifier: String?
  
  public override class func defaultDirectoryURL() -> URL {
    if let applicationGroupIdentifier = applicationGroupIdentifier {
      return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: applicationGroupIdentifier)!
    } else {
      return super.defaultDirectoryURL()
    }
  }
  
  public static var shared: InMemoryContainer = {
    /*
     The persistent container for the application. This implementation
     creates and returns a container, having loaded the store for the
     application to it. This property is optional since there are legitimate
     error conditions that could cause the creation of the store to fail.
     */
    
    let container = InMemoryContainer(name: "Pod2Watch")

    if MPMediaLibrary.authorizationStatus() == .authorized {
      container.reloadPodcastLibrary()
    }
    
    NotificationCenter.default.addObserver(forName: Notification.Name.MPMediaLibraryDidChange,
                                           object: nil,
                                           queue: OperationQueue.main) { [unowned container] _ in
                                            container.reloadPodcastLibrary()
    }
    
    MPMediaLibrary.default().beginGeneratingLibraryChangeNotifications()
    
    
    container.viewContext.mergePolicy = NSMergePolicy.overwrite
    
    return container
  }()
  
  func reloadPodcastLibrary() {
    if let store = persistentStoreCoordinator.persistentStores.first {
      try! persistentStoreCoordinator.remove(store)
    }
    
    try! persistentStoreCoordinator.addPersistentStore(ofType: NSInMemoryStoreType,
                                                       configurationName: nil,
                                                       at: nil,
                                                       options: nil)
    
    let allQuery = MPMediaQuery.podcasts()
    allQuery.groupingType = .podcastTitle
    
    guard let collections = allQuery.collections else {
      return
    }
    
    for collection in collections {
      guard let representativeItem = collection.representativeItem else {
        return
      }
      
      let request: NSFetchRequest<LibraryPodcast> = LibraryPodcast.fetchRequest()
      request.predicate = NSPredicate(format: "title == %@", representativeItem.podcastTitle ?? "")
      request.fetchLimit = 1
      
      let podcast: LibraryPodcast
      
      if let existingPodcast = (try? viewContext.fetch(request))?.first {
        podcast = existingPodcast
      } else {
        podcast = LibraryPodcast(mediaItem: representativeItem, context: viewContext)
      }
      
      let episodes = collection.items.filter({ mediaItem in
        if let _ = mediaItem.assetURL {
          return true
        } else {
          return false
        }
      }).map({ mediaItem -> LibraryEpisode in
        let episode = LibraryEpisode(mediaItem: mediaItem, context: viewContext)
        episode.podcast = podcast
        
        return episode
      })
      
      podcast.addToEpisodes(NSOrderedSet(array: episodes))
    }
  }
  
  class func saveContext () {
    let context = shared.viewContext
    if context.hasChanges {
      do {
        try context.save()
      } catch {
        // Replace this implementation with code to handle the error appropriately.
        // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
        let nserror = error as NSError
        fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
      }
    }
  }
}
