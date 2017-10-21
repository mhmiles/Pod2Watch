//
//  TransferredEpisode.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 3/25/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import UIKit
import CoreData
import ReactiveSwift
import enum Result.NoError
import Alamofire
import AlamofireImage
import WatchConnectivity.WCSessionFile

public class TransferredEpisode: NSManagedObject {
    var transfer: WCSessionFileTransfer?
    
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
    
    class func existing(persistentID: Int64) -> TransferredEpisode? {
        let request: NSFetchRequest<TransferredEpisode> = TransferredEpisode.fetchRequest()
        request.predicate = NSPredicate(format: "persistentID == %ld", persistentID)
        request.fetchLimit = 1
        
        let existing = try? PersistentContainer.shared.viewContext.fetch(request)
        return existing?.first
    }
    
    class func existing(persistentIDs: [Int64]) -> [TransferredEpisode] {
        let request: NSFetchRequest<TransferredEpisode> = TransferredEpisode.fetchRequest()
        request.predicate = NSPredicate(format: "persistentID IN %@", persistentIDs)
        
        return  try! PersistentContainer.shared.viewContext.fetch(request)
    }
    
    class func pendingTransfers() -> [TransferredEpisode] {
        let request: NSFetchRequest<TransferredEpisode> = fetchRequest()
        request.predicate = NSPredicate(format: "hasBegunTransfer == NO")
        
        return try! PersistentContainer.shared.viewContext.fetch(request)
    }
    
    class func pendingDeletes() -> [TransferredEpisode] {
        let request: NSFetchRequest<TransferredEpisode> = TransferredEpisode.fetchRequest()
        request.predicate = NSPredicate(format: "shouldDelete == YES")
        
        return try! PersistentContainer.shared.viewContext.fetch(request)
    }
    
    class func all() -> [TransferredEpisode] {
        let request: NSFetchRequest<TransferredEpisode> = TransferredEpisode.fetchRequest()
        
        return try! PersistentContainer.shared.viewContext.fetch(request)
    }
    
    convenience init(_ episode: LibraryEpisode) {
        let context = PersistentContainer.shared.viewContext
        let entity = NSEntityDescription.entity(forEntityName: "TransferredEpisode", in: context)!
        self.init(entity: entity, insertInto: context)
        
        persistentID = episode.persistentID
        title = episode.title
        releaseDate = episode.releaseDate
        playbackDuration = episode.playbackDuration
    }
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        
        let request: NSFetchRequest<TransferredEpisode> = TransferredEpisode.fetchRequest()
        request.fetchLimit = 1
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(TransferredEpisode.sortIndex),
                                                    ascending: true)]
        
        let context = PersistentContainer.shared.viewContext
        sortIndex = (try? context.fetch(request))?.first.map({ $0.sortIndex-1 }) ?? 0
    }
    
    var podcastArtworkImage: UIImage? {
        guard let podcastTitle = podcast?.title else {
            return nil
        }
        
        return LibraryPodcast.artworkCache.image(withIdentifier: podcastTitle)
    }
    
    var podcastArtworkProducer: SignalProducer<UIImage?, NoError> {
        return SignalProducer<UIImage?, NoError> { [unowned self] (observer, _) in
            if let podcastTitle = self.podcast?.title,
                let artworkImage = LibraryPodcast.artworkCache.image(withIdentifier: podcastTitle) {
                observer.send(value: artworkImage)
                observer.sendCompleted()
            } else {
                observer.send(value: nil)
                
                guard let podcastTitle = self.podcast?.title, podcastTitle != "" else {
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
                                                    if let podcastTitle = self.podcast?.title, podcastTitle != "" {
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
    
    var watchEpisodeCellViewModel: WatchEpisodeCellViewModel {
        let syncState: SyncState?
        
        if isTransferred {
            syncState = nil
        } else if hasBegunTransfer {
            syncState = .syncing
        } else {
            syncState = .pending
        }
        
        return WatchEpisodeCellViewModel(identifier: persistentID,
                                         title: title,
                                         secondaryLabelText: secondaryLabelText,
                                         syncState: syncState,
                                         artworkImage: podcast?.artworkImage)
    }
}
