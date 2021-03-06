//
//  LibraryEpisode.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 4/20/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import Foundation
import MediaPlayer
import CoreData
import ReactiveSwift
import enum Result.NoError
import Alamofire

public class LibraryEpisode: NSManagedObject {
    var mediaItem: MPMediaItem!
    
    var assetURL: URL? {
        return mediaItem.assetURL
    }
    
    var title: String? {
        return mediaItem.title
    }
    
    var artwork: MPMediaItemArtwork? {
        return mediaItem.artwork
    }
    
    class func existing(persistentID: Int64) -> LibraryEpisode?  {
        let request: NSFetchRequest<LibraryEpisode> = LibraryEpisode.fetchRequest()
        request.predicate = NSPredicate(format: "persistentID == %ld", persistentID)
        request.fetchLimit = 1
        
        let existing = try? InMemoryContainer.shared.viewContext.fetch(request)
        return existing?.first
    }
    
    class func latestEpisode(title: String) -> LibraryEpisode? {
        let request: NSFetchRequest<LibraryEpisode> = LibraryEpisode.fetchRequest()
        request.predicate = NSPredicate(format: "podcast.title == %@", title)
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(LibraryEpisode.releaseDate),
                                                    ascending: false)]
        request.fetchLimit = 1
        
        let latest = try? InMemoryContainer.shared.viewContext.fetch(request)
        return latest?.first
    }
    
    convenience init(mediaItem: MPMediaItem, context: NSManagedObjectContext) {
        self.init(context: context)
        
        self.mediaItem = mediaItem
        
        persistentID = Int64(bitPattern: mediaItem.persistentID)
        
        if mediaItem.playbackDuration < 1 {
            let asset = AVURLAsset(url: mediaItem.assetURL!)
            playbackDuration = asset.duration.seconds
        } else {
            playbackDuration = mediaItem.playbackDuration
        }
        
        releaseDate = mediaItem.releaseDate
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
        
        if let label = cutoffDates.first(where: { releaseDate as Date > $0.0 })?.1 {
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
        } else if let podcastTitle = title,
            podcastTitle != "",
            let image = LibraryPodcast.artworkCache.image(withIdentifier: podcastTitle) {
            return image
        } else {
            return nil
        }
    }
    
    var podcastArtworkProducer: SignalProducer<UIImage?, NoError> {
        return SignalProducer<UIImage?, NoError> { [unowned self] (observer, _) in
            if let artworkImage = self.artworkImage {
                observer.send(value: artworkImage)
                observer.sendCompleted()
            } else {
                observer.send(value: nil)
                
                guard let podcastTitle = self.title, podcastTitle != "" else {
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
                                                    if let podcastTitle = self.title, podcastTitle != "" {
                                                        LibraryPodcast.artworkCache.add(image, withIdentifier: podcastTitle)
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
    
    var podcastEpisodeCellViewModel: PodcastEpisodeCellViewModel {
        let syncState = self.syncState(for: persistentID) ?? .noSync
        let syncHandler = syncState == .noSync ? { PodcastTransferManager.shared.transfer(self) } : {}

        return PodcastEpisodeCellViewModel(identifier: persistentID,
                                           title: title,
                                           secondaryLabelText: secondaryLabelText,
                                           syncHandler: syncHandler,
                                           syncState: syncState)
    }
    
    var recentEpisodeCellViewModel: RecentEpisodeCellViewModel {
        let syncState = self.syncState(for: persistentID) ?? .noSync
        let syncHandler = syncState == .noSync ? { PodcastTransferManager.shared.transfer(self) } : {}
        
        return RecentEpisodeCellViewModel(identifier: persistentID,
                                          title: title,
                                          secondaryLabelText: recentSecondaryLabelText,
                                          syncHandler: syncHandler,
                                          syncState: syncState,
                                          artworkProducer: podcastArtworkProducer)
    }
    
    private func syncState(for identifier: Int64) -> SyncState? {
        guard let existing = TransferredEpisode.existing(persistentID: identifier) else {
            return nil
        }
        
        if existing.shouldDelete {
            return .pending
        } else if existing.isTransferred {
            return .synced
        } else {
            return .syncing
        }
    }
}
