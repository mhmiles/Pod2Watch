//
//  LibraryPodcastEpisode.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 3/24/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import UIKit
import MediaPlayer.MPMediaItem
import ReactiveSwift
import Alamofire
import AlamofireImage
import enum Result.NoError
import CoreData
import IGListKit.IGListDiffable

enum ReleaseDateGoup: Int {
  case future
  case today
  case yesterday
  case twoDaysAgo
  case threeDaysAgo
  case fourDaysAgo
  case fiveDaysAgo
  case thisMonth
  case lastThreeMonths
  case lastSixMonths
  case past
}

class LibraryPodcastEpisode: NSManagedObject {
  static let artworkCache = AutoPurgingImageCache()
  
  private var mediaItem: MPMediaItem!
  
  var assetURL: URL {
    return mediaItem.assetURL!
  }

  var episodeTitle: String {
    return mediaItem.title!
  }

  @objc var releaseDateLabel: String! {
    guard let releaseDate = releaseDate else {
      return "Unknown Date"
    }
    
    let calendar = NSCalendar.current
    
    let startOfCurrentDay = calendar.startOfDay(for: Date())
    
    let formatter = DateFormatter()
    formatter.dateFormat = "EEEE"
    
    let cutoffDates: [(Date, String)] = [
      (calendar.date(byAdding: .day, value: 1, to: startOfCurrentDay), "Future"),
      (startOfCurrentDay, "Today"),
      (calendar.date(byAdding: .day, value: -1, to: startOfCurrentDay), "Yesterday"),
      (calendar.date(byAdding: .day, value: -2, to: startOfCurrentDay), nil),
      (calendar.date(byAdding: .day, value: -3, to: startOfCurrentDay), nil),
      (calendar.date(byAdding: .day, value: -4, to: startOfCurrentDay), nil),
      (calendar.date(byAdding: .day, value: -5, to: startOfCurrentDay), nil),
      (calendar.date(byAdding: .day, value: -6, to: startOfCurrentDay), nil),
      (calendar.date(byAdding: .month, value: -1, to: startOfCurrentDay), "This Month"),
      (calendar.date(byAdding: .month, value: -3, to: startOfCurrentDay), "Last 3 Months"),
      (calendar.date(byAdding: .month, value: -6, to: startOfCurrentDay), "Last 6 Months")
      ].map {
        return ($0!, $1 ?? formatter.string(from: $0!))
    }
    
    if let label = cutoffDates.first(where: { releaseDate as Date > $0.0 })?.1  {
      return label
    } else {
      let cutoffDateComponents = calendar.dateComponents([.year, .month, .day], from: releaseDate as Date)
      let startOfYear = calendar.date(from: DateComponents(year: cutoffDateComponents.year!))!
      
      formatter.dateFormat = "yyyy"
      
      return formatter.string(from: startOfYear)
    }
  }
  
  var artworkImage: UIImage? {
    if let artwork = mediaItem.artwork {
      return artwork.image(at: artwork.bounds.size)
    } else if let podcastTitle = podcastTitle,
      podcastTitle != "",
      let image = LibraryPodcastEpisode.artworkCache.image(withIdentifier: podcastTitle) {
      return image
    } else {
      return nil
    }
  }
  
  var podcastArtworkProducer: SignalProducer<UIImage?, NoError> {
    return SignalProducer<UIImage?, NoError> { [unowned self] (observer, disposable) in
      if let artworkImage = self.artworkImage {
        observer.send(value: artworkImage)
        observer.sendCompleted()
      } else {
        observer.send(value: nil)
        
        guard let podcastTitle = self.podcastTitle, podcastTitle != "" else {
          return
        }
        
        let searchParameters = ["term": podcastTitle,
                                "media": "podcast"]
        
        Alamofire.request("https://itunes.apple.com/search",
                          parameters: searchParameters).responseJSON { response in
                            switch response.result {
                            case .success(let json as NSDictionary):
                              if let results = json["results"] as? [NSDictionary],
                                let artworkURL = results.first?["artworkUrl600"] as? String {
                                Alamofire.request(artworkURL).responseImage(completionHandler: { response in
                                  switch response.result {
                                  case .success(let image):
                                    if let podcastTitle = self.podcastTitle, podcastTitle != "" {
                                      LibraryPodcastEpisode.artworkCache.add(image, withIdentifier: podcastTitle)
                                    }
                                    
                                    observer.send(value: image)
                                    observer.sendCompleted()
                                    
                                  case .failure(let error):
                                    print(error)
                                  }
                                })
                              }
                              
                            case .failure(let error):
                              print(error)
                              
                            default:
                              print("Invalid response")
                            }
        }
        
      }
    }
  }
  
  var secondaryLabelText: String {
    var durationString = ""
    
    if let releaseDate = releaseDate as Date? {
      let calendar = Calendar.current
      let formatter = DateFormatter()
      
      formatter.timeZone = calendar.timeZone
      
      if calendar.dateComponents([.day], from: calendar.startOfDay(for: releaseDate), to: calendar.startOfDay(for: Date())).day! > 6 {
        if calendar.dateComponents([.year], from: Date()) != calendar.dateComponents([.year], from: releaseDate) {
          formatter.dateFormat = "MMM d, YYYY"
        } else {
          formatter.dateFormat = "MMM d"
        }
        
        durationString += formatter.string(from: releaseDate) + " • "
      } else {
        durationString += releaseDateLabel + " • "
      }
    }
    
    let minuteDuration = Int(ceil(playbackDuration/60.0))
    
    if minuteDuration > 60 {
      durationString += "\(minuteDuration/60) hr "
    }
    
    if minuteDuration % 60 > 0 {
      durationString += "\(minuteDuration%60) min"
    }
    
    return durationString
  }
  
  var recentSecondaryLabelText: String {
    var durationString = ""
    
    if let releaseDate = releaseDate as Date? {
      let calendar = Calendar.current
      let formatter = DateFormatter()
      
      formatter.timeZone = calendar.timeZone
      
      if calendar.dateComponents([.day], from: calendar.startOfDay(for: releaseDate), to: calendar.startOfDay(for: Date())).day! > 6 {
        if calendar.dateComponents([.year], from: Date()) != calendar.dateComponents([.year], from: releaseDate) {
          formatter.dateFormat = "MMM d, YYYY"
        } else {
          formatter.dateFormat = "MMM d"
        }
        
        durationString += formatter.string(from: releaseDate) + " • "
      }
    }
    
    let minuteDuration = Int(ceil(playbackDuration/60.0))
    
    if minuteDuration > 60 {
      durationString += "\(minuteDuration/60) hr "
    }
    
    if minuteDuration % 60 > 0 {
      durationString += "\(minuteDuration%60) min"
    }
    
    return durationString
  }
  
  convenience init(mediaItem: MPMediaItem, context: NSManagedObjectContext) {
    let context = context
    let entity = NSEntityDescription.entity(forEntityName: "LibraryPodcastEpisode", in: context)!
    
    self.init(entity: entity, insertInto: context)
    
    self.mediaItem = mediaItem
    podcastTitle = mediaItem.podcastTitle
    podcastTitleWithoutThe = podcastTitle?.withoutThe
    podcastID = Int64(bitPattern: mediaItem.podcastPersistentID)
    
    if mediaItem.playbackDuration == 0 {
      let asset = AVURLAsset(url: mediaItem.assetURL!)
      playbackDuration = asset.duration.seconds
    } else {
      playbackDuration = mediaItem.playbackDuration
    }
    
    releaseDate = mediaItem.releaseDate as NSDate?
  }

}

extension LibraryPodcastEpisode: IGListDiffable {
  public func diffIdentifier() -> NSObjectProtocol {
    return (podcastTitle ?? "") as NSObjectProtocol
  }
  
  public func isEqual(toDiffableObject object: IGListDiffable?) -> Bool {
    guard let podcast = object as? LibraryPodcastEpisode else {
      return false
    }
    
    return podcast.podcastTitle == podcastTitle
  }
}
