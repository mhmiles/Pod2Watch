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

class PodcastDownloadManager {
  static let shared = PodcastDownloadManager()
  
  var podcastsRequest: DataRequest?
  
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
}
