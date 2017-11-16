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
import Alamofire
import ReactiveSwift

public class Episode: NSManagedObject {
  @nonobjc public class func fetchRequest() -> NSFetchRequest<Episode> {
    return NSFetchRequest<Episode>(entityName: "Episode")
  }
  
  @NSManaged public var podcast: Podcast
  @NSManaged public var title: String?
  @NSManaged public var fileURL: URL?
  @NSManaged public var playbackDuration: Double
  @NSManaged public var persistentID: Int64
  @NSManaged public var sortIndex: Int16
  @NSManaged public var startTime: Double
  @NSManaged public var isDownload: Bool
  @NSManaged public var downloadProgress: Double
  @NSManaged public var remoteURLString: String?
  
  var downloadRequest: DownloadRequest? {
    willSet {
      downloadRequest?.cancel()
    }
    didSet {
      var disposable: Disposable?
      
      if let _ = downloadRequest {
        disposable = SignalProducer.timer(interval: .seconds(5), on: QueueScheduler.main).startWithValues({ [unowned self] (_) in
          self.updateProgress()
        })
      }
      
      downloadProgressDisposable = disposable.map { ScopedDisposable($0) }
    }
  }
  
  var remoteURL: URL? {
    get {
      return remoteURLString.flatMap { URL(string: $0) }
    } set {
      remoteURLString = newValue.map { $0.absoluteString }
    }
  }
  
//  var downloadTask: URLSessionDownloadTask? {
//    willSet {
//      downloadTask?.cancel()
//    }
//    didSet {
//      var disposable: Disposable?
//
//      if let downloadTask = downloadTask {
//        downloadTask.resume()
//
//        disposable = SignalProducer.timer(interval: .seconds(5), on: QueueScheduler.main).startWithValues({ [unowned self] (_) in
//          self.updateProgress()
//        })
//      }
//
//      downloadProgressDisposable = disposable.map { ScopedDisposable($0) }
//    }
//  }
  
  private func updateProgress() {
    downloadProgress = downloadRequest?.progress.fractionCompleted ?? 0
  }
  
  private var downloadProgressDisposable: ScopedDisposable<AnyDisposable>?
  
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
  
  class func existing(remoteURL: URL) -> Episode? {
    let request: NSFetchRequest<Episode> = fetchRequest()
    request.predicate = NSPredicate(format: "remoteURLString == %@", remoteURL.absoluteString)
    request.fetchLimit = 1
    
    return try! PersistentContainer.shared.viewContext.fetch(request).first
  }
  
  class func all() -> [Episode] {
    let request: NSFetchRequest<Episode> = Episode.fetchRequest()
    return try! PersistentContainer.shared.viewContext.fetch(request)
  }
}
