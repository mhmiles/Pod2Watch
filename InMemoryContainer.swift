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

    try! container.persistentStoreCoordinator.addPersistentStore(ofType: NSInMemoryStoreType,
                                        configurationName: nil,
                                        at: nil,
                                        options: nil)
    

    
    if MPMediaLibrary.authorizationStatus() == .authorized {
      container.loadPodcastLibrary()
    }
    
    container.viewContext.mergePolicy = NSMergePolicy.overwrite
    
    return container
  }()
  
  func loadPodcastLibrary() {
    let allQuery = MPMediaQuery.podcasts()
    
    guard let podcastEpisodes = allQuery.items else {
      return
    }
    
    podcastEpisodes.forEach { let _ = LibraryPodcastEpisode(mediaItem:$0, context: viewContext) }
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
