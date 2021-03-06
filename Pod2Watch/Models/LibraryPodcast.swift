//
//  LibraryPodcast.swift
//  Pod2Watch
//
//  Created by Miles Hollingsworth on 4/20/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import Foundation
import Alamofire
import AlamofireImage
import IGListKit
import ReactiveSwift
import enum Result.NoError
import MediaPlayer
import CoreData

extension LibraryPodcast {
  static let artworkCache = AutoPurgingImageCache()

  @objc var titleWithoutThe: String? {
    return title?.withoutThe
  }

  var artworkImage: UIImage? {
    if let episode = episodes?.firstObject as? LibraryEpisode,
      let artwork = episode.artwork {
      return artwork.image(at: artwork.bounds.size)
    } else if let title = title,
      title != "",
      let image = LibraryPodcast.artworkCache.image(withIdentifier: title) {
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
      } else if let podcast = TransferredPodcast.existing(title: self.title!),
        let artworkImage = podcast.artworkImage {
        if let title = self.title, title != "" {
          LibraryPodcast.artworkCache.add(artworkImage, withIdentifier: title)
        }

        observer.send(value: artworkImage)
        observer.sendCompleted()
      } else {
        observer.send(value: nil)

        guard let title = self.title, title != "" else {
          return
        }

        let searchParameters = ["term": title,
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
                                    if let title = self.title, title != "" {
                                      LibraryPodcast.artworkCache.add(image, withIdentifier: title)
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

  class func existing(title: String, context: NSManagedObjectContext = InMemoryContainer.shared.viewContext) -> LibraryPodcast? {
    guard title.count > 0 else {
      return nil
    }
    
    let request: NSFetchRequest<LibraryPodcast> = fetchRequest()
    request.predicate = NSPredicate(format: "title MATCHES[cd] %@", title)
    request.fetchLimit = 1

    let existing = try? context.fetch(request)
    return existing?.first
  }

  convenience init(mediaItem: MPMediaItem, context: NSManagedObjectContext) {
    self.init(context: context)

    title = mediaItem.podcastTitle
  }
  
  var podcastCellViewModel: PodcastCellViewModel {
    return PodcastCellViewModel(title: title ?? "",
                                artworkProducer: podcastArtworkProducer)
  }
}
