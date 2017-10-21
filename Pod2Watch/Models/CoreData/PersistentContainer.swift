//
//  PersistentContainer.swift
//  GoogleCastSwift
//
//  Created by Miles Hollingsworth on 2/5/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import UIKit
import CoreData

public final class PersistentContainer: NSPersistentContainer {
  public static var applicationGroupIdentifier: String?

  public override class func defaultDirectoryURL() -> URL {
    if let applicationGroupIdentifier = applicationGroupIdentifier {
      return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: applicationGroupIdentifier)!
    } else {
      return super.defaultDirectoryURL()
    }
  }

  public static var shared: PersistentContainer = {
    /*
     The persistent container for the application. This implementation
     creates and returns a container, having loaded the store for the
     application to it. This property is optional since there are legitimate
     error conditions that could cause the creation of the store to fail.
     */

    ValueTransformer.setValueTransformer(UIImageTransformer(), forName: NSValueTransformerName("UIImageTransformer"))
    ValueTransformer.setValueTransformer(URLTransformer(), forName: NSValueTransformerName("URLTransformer"))

    let container = PersistentContainer(name: "Pod2WatchPersistent")

    container.loadPersistentStores(completionHandler: { (_, error) in
      if let error = error as NSError? {
        // Replace this implementation with code to handle the error appropriately.
        // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

        /*
         Typical reasons for an error here include:
         * The parent directory does not exist, cannot be created, or disallows writing.
         * The persistent store is not accessible, due to permissions or data protection when the device is locked.
         * The device is out of space.
         * The store could not be migrated to the current model version.
         Check the error message to determine what the actual problem was.
         */
        fatalError("Unresolved error \(error), \(error.userInfo)")
      }
    })

//    print(container.persistentStoreCoordinator.persistentStores.first?.identifier)

    container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump

    return container
  }()

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
  
  func reset() {
    let context = viewContext
    
    context.perform {
      for episode in TransferredEpisode.all() {
        episode.podcast?.removeFromEpisodes(episode)
        context.delete(episode)
      }
      
      PersistentContainer.saveContext()
    }
  }
}
