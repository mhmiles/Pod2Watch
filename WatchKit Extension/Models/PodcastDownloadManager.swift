//
//  PodcastDownloadManager.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 10/22/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import Foundation
import Alamofire
import SWXMLHash
import CoreData
import WatchKit
import UserNotifications

private let backgroundTaskIdentifider = "com.hollingsware.pod2watch.podcast-download"

private let saveDirectoryURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.hollingsware.pod2watch")!.appendingPathComponent("Episodes", isDirectory: true)


class PodcastDownloadManager: NSObject {
  static let shared = PodcastDownloadManager()
  
  var podcastsRequest: DataRequest?
  
  var backgrounndRefreshTask: WKURLSessionRefreshBackgroundTask?
  
  private lazy var foregroundSession: URLSession = {
    let configuration = URLSessionConfiguration.default
    
    return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
  }()
  
  fileprivate var requestRedirectMap = [URL: URL]()
  
  private lazy var backgroundSession: URLSession = {
    let configuration = URLSessionConfiguration.background(withIdentifier: backgroundTaskIdentifider)
    
    return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
  }()
  
  private lazy var __notificationOnce: () = {
    NotificationCenter.default.post(name: .podcastDownloadDidBegin,
                                    object: self,
                                    userInfo: nil)
  }()
  
  override init() {
    super.init()
    
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(PodcastDownloadManager.handleApplicationWillResignActive),
                                           name: Notification.Name(rawValue: "UIApplicationWillResignActiveNotification"),
                                           object: nil)
    
    //Start up background session to check for completed downloads
    let _ = backgroundSession
  }
  
  func handleSearch(term: String, completion: @escaping ([PodcastDetails]?, Error?) -> Void) {
    podcastsRequest?.cancel()
    
    let parameters = ["term": term, "entity": "podcast"]
    podcastsRequest = Alamofire.request("https://itunes.apple.com/search", parameters: parameters).response { (response) in
      guard let data = response.data else {
        print(response.error as Any)
        completion(nil, response.error)
        return
      }
      
      let decoder = JSONDecoder()
      do {
        let response = try decoder.decode(PodcastDetailsResponse.self, from: data)
        
        let podcasts = response.results.filter { $0.feedURL != nil }
        completion(podcasts, nil)
      } catch let error {
        print(response.data as Any)
        completion(nil, error)
      }
    }
  }
  
  func downloadTopPodcasts(completion: @escaping ([TopPodcastDetails]?, Error?) -> Void) {
    podcastsRequest?.cancel()
    
    podcastsRequest = Alamofire.request("https://rss.itunes.apple.com/api/v1/us/podcasts/top-podcasts/all/50/explicit.json").response { (response) in
      guard let data = response.data else {
        completion(nil, response.error)
        return
      }
      
      let decoder = JSONDecoder()
      do {
        let response = try decoder.decode(TopPodcastsRepsonse.self, from: data)
        completion(response.feed.results, nil)
      } catch let error {
        completion(nil, error)
      }
    }
  }
  
  func getEpisodes(podcast: PodcastFeedProvider, completion: @escaping ([DownloadEpisode]?, Error?) -> Void) {
    guard let feedURL = podcast.feedURL else {
      return
    }
    
    podcastsRequest = Alamofire.request(feedURL).response { (response) in
      guard let data = response.data else {
        completion(nil, response.error)
        return
      }
      
      let xml = SWXMLHash.config {
        config in
        config.shouldProcessLazily = true
        }.parse(data)
      
      let items = xml["rss"]["channel"]["item"].all
      let episodes = items.flatMap({ (item) -> DownloadEpisode? in
        let itunesDuration = item["itunes:duration"].element?.text
        let duration = itunesDuration.map({ (durationString) -> TimeInterval in
          let durationComponents = durationString.split(separator: ":")
          
          return durationComponents.reversed().enumerated().reduce(0, {(accum, durationTuple) in
            guard let duration = TimeInterval(durationTuple.element) else {
              return accum
            }
            
            let currentPlace = pow(60, TimeInterval(durationTuple.offset))
            return accum + duration*currentPlace
          })
        })
        
        
        let formatter = DateFormatter()
        formatter.dateFormat = "E, d MMM yyyy HH:mm:ss Z"
        let pubdate = item["pubDate"].element?.text
        let releaseDate = pubdate.flatMap(formatter.date)
        
        if let guid = item["guid"].element?.text,
          let title = item["title"].element?.text,
          let releaseDate = releaseDate,
          let mediaUrlString = item["enclosure"].element?.attribute(by: "url")?.text,
          let mediaURL = URL(string: mediaUrlString) {
          return  DownloadEpisode(persistentID: Int64(guid.hashValue),
                                  title: title,
                                  podcastTitle: podcast.name,
                                  playbackDuration: duration ?? 0,
                                  releaseDate: releaseDate,
                                  mediaURL: mediaURL,
                                  artworkURL: podcast.artworkURL)
        } else {
          return nil
        }
      })
      
      completion(episodes, nil)
    }
  }
  
  func getFeedURL(id: Int, completion: @escaping (PodcastDetails?, Error?) -> Void) {
    let parameters: [String: Any] = ["id": id, "entity": "podcast"]
    podcastsRequest = Alamofire.request("https://itunes.apple.com/lookup", parameters: parameters).response { (response) in
      guard let data = response.data else {
        completion(nil, response.error)
        return
      }
      
      let decoder = JSONDecoder()
      do {
        let response = try decoder.decode(PodcastDetailsResponse.self, from: data)
        
        if let podcast = response.results.first {
          completion(podcast, nil)
        } else {
          //          self?.presentController(withName: "FeedError", context: nil)
        }
      } catch let error {
        completion(nil, error)
      }
    }
  }
  
  @objc func handleApplicationWillResignActive() {
    foregroundSession.getAllTasks { (tasks) in
      for task in tasks.flatMap({ $0 as? URLSessionDownloadTask }) {
        task.cancel { (resumeData) in
          let task = resumeData.map(self.backgroundSession.downloadTask)
          task?.resume()
        }
      }
    }
  }
  
  func download(episode: DownloadEpisode) throws {
    _ = __notificationOnce
    
    let existingPodcast = Podcast.existing(title: episode.podcastTitle)
    
    if let existingPodcast = existingPodcast  {
      let request: NSFetchRequest<Episode> = Episode.fetchRequest()
      
      request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
        NSPredicate(format: "persistentID == %ld",
                    episode.persistentID),
        NSPredicate(format: "podcast == %@ && title == %@",
                    existingPodcast,
                    episode.title)
        ])
      
      request.fetchLimit = 1
      
      if let _ = (try PersistentContainer.shared.viewContext.fetch(request)).first {
        throw DownloadError.episodeExists
      }
    }
    
    let context = PersistentContainer.shared.viewContext
    
    let localEpisode = Episode(context: context)
    localEpisode.persistentID = episode.persistentID
    localEpisode.title = episode.title
    localEpisode.playbackDuration = episode.playbackDuration
    localEpisode.isDownload = true
    
    let request: NSFetchRequest<Episode> = Episode.fetchRequest()
    request.sortDescriptors = [NSSortDescriptor(key: "sortIndex", ascending: true)]
    request.fetchLimit = 1
    localEpisode.sortIndex = ((try? context.fetch(request))?.first?.sortIndex ?? 1)-1
    
    let podcast = existingPodcast ?? Podcast(title: episode.podcastTitle,
                                             context: context)
    
    podcast.addToEpisodes(localEpisode)
    
    let url = episode.mediaURL
    
    guard let host = url.host,
      let httpsURL = URL(string: "https://" + host + url.relativePath) else {
        PersistentContainer.shared.viewContext.delete(localEpisode)
        return
    }
    
    localEpisode.remoteURL = httpsURL
    
    PersistentContainer.saveContext()
    
    let task = foregroundSession.downloadTask(with: httpsURL)
    task.resume()
    
    Alamofire.request(episode.artworkURL).responseImage(completionHandler: { (response) in
      switch response.result {
      case .success(let image):
        podcast.artworkImage = image
        
      case .failure(let error):
        print(error)
      }
    })
    
    PodcastTransferManager.shared.sendWatchDownload(episode: episode, sortIndex: localEpisode.sortIndex)
  }
  
  func cancelAllTransfers() {
    foregroundSession.getAllTasks { (tasks) in
      tasks.forEach { $0.cancel() }
    }
    
    backgroundSession.getAllTasks { (tasks) in
      tasks.forEach { $0.cancel() }
    }
  }
}

extension PodcastDownloadManager: URLSessionDownloadDelegate {
  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    guard session == backgroundSession,
      let error = error,
      let url = task.originalRequest?.url,
      let existing = Episode.existing(remoteURL: url)  else { return }
    
    let userInfo = [
      "podcastTitle": existing.podcast.title,
      "episodeTitle": existing.title ?? ""
    ]
    
    PodcastTransferManager.shared.delete(existing)
    
    if (error as NSError).code == 22  {
      NotificationCenter.default.post(name: .podcastSecurityFailed, object: self, userInfo: userInfo)
    }
  }
  
  func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    backgrounndRefreshTask?.setTaskCompletedWithSnapshot(true)
  }
  
  func urlSession(_ session: URLSession,
                  task: URLSessionTask,
                  willPerformHTTPRedirection response: HTTPURLResponse,
                  newRequest request: URLRequest,
                  completionHandler: @escaping (URLRequest?) -> Void) {
    if let originalURL = task.originalRequest?.url, let newURL = request.url {
      requestRedirectMap[originalURL] = newURL
    }
    
    completionHandler(request)
  }
  
  func urlSession(_ session: URLSession,
                  downloadTask: URLSessionDownloadTask,
                  didWriteData bytesWritten: Int64,
                  totalBytesWritten: Int64,
                  totalBytesExpectedToWrite: Int64) {
    guard let originalURL = downloadTask.originalRequest?.url,
      let existing = Episode.existing(remoteURL: originalURL) else { return }
    
    guard session == backgroundSession else {
      downloadTask.cancel()
      
      let finalURL = requestRedirectMap.removeValue(forKey: originalURL) ?? originalURL
      
      PersistentContainer.shared.viewContext.perform {
        existing.remoteURL = finalURL
        PersistentContainer.saveContext()
      }
      
      let task = backgroundSession.downloadTask(with: finalURL)
      task.resume()
      
      return
    }
    
    PersistentContainer.shared.viewContext.perform {
      existing.downloadProgress = Double(totalBytesWritten/1024)/Double(totalBytesExpectedToWrite/1024)
      PersistentContainer.saveContext()
    }
  }
  
  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    guard let remoteURL = downloadTask.originalRequest?.url,
      let existing = Episode.existing(remoteURL: remoteURL) else { return }
    
    let destination = saveDirectoryURL.appendingPathComponent(remoteURL.lastPathComponent)
    let fileManager = FileManager.default
    
    do {
      if fileManager.fileExists(atPath: destination.relativePath) {
        try fileManager.removeItem(at: destination)
      }
      
      if fileManager.fileExists(atPath: saveDirectoryURL.path) == false {
        try fileManager.createDirectory(at: saveDirectoryURL,
                                        withIntermediateDirectories: false,
                                        attributes: nil)
      }
      
      try fileManager.moveItem(at: location, to: destination)
      
      PersistentContainer.shared.viewContext.perform {
        existing.fileURL = destination
        PersistentContainer.saveContext()
      }
      
      let content = UNMutableNotificationContent()
      content.title = "\(existing.title ?? "") has completed downloading."
      content.sound = UNNotificationSound.default()
      
      let request = UNNotificationRequest(identifier: "com.hollingsware.pod2watch.download_complete",
                                          content: content,
                                          trigger: nil)
      
      UNUserNotificationCenter.current().add(request, withCompletionHandler: { (error) in
        if let error = error {
          print(error)
        }
      })
    } catch let error {
      print(error)
    }
  }
}

extension NSNotification.Name {
  static let podcastSecurityFailed = NSNotification.Name("PodcastSecurityFailed")
  static let podcastDownloadDidBegin = Notification.Name(rawValue: "PodcastDownloadDidBegin")
}
