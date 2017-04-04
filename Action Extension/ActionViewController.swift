//
//  ActionViewController.swift
//  Action Extension
//
//  Created by Miles Hollingsworth on 2/8/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import UIKit
import MobileCoreServices
import CoreData
import PodcastFeedFinder
import Alamofire
import Fuzi

class ActionViewController: UIViewController {
  
  @IBOutlet weak var imageView: UIImageView!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Get the item[s] we're handling from the extension context.
    
    // For example, look for an image and place it into an image view.
    // Replace this with something appropriate for the type[s] your extension supports.
    var imageFound = false
    for item in self.extensionContext!.inputItems as! [NSExtensionItem] {
      for provider in item.attachments! as! [NSItemProvider] {
        if provider.hasItemConformingToTypeIdentifier(kUTTypeText as String) {
          // This is an image. We'll load it, then place it in our image view.
          
          provider.loadItem(forTypeIdentifier: kUTTypeText as String, options: nil, completionHandler: { (item, error) in
            guard let string = item as? String else {
              return
            }
            
            let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
            
            if let result = detector.firstMatch(in: string, options: NSRegularExpression.MatchingOptions(), range: NSMakeRange(0, string.characters.count)),
              let url = result.url {
              if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                var podcastID = components.queryItems?.filter({$0.name == "i"}).first?.value {
                let mutableRequest = NSMutableURLRequest(url: url)
                mutableRequest.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_4) AppleWebKit/600.7.12 (KHTML, like Gecko) Version/8.0.7 Safari/600.7.12",
                                        forHTTPHeaderField: "User-Agent")
                
                if podcastID.hasPrefix("1000"), podcastID.characters.count > 9 {
                  podcastID = podcastID.substring(from:  podcastID.index(podcastID.startIndex, offsetBy: 4))
                }
                
                let request = mutableRequest.copy() as! URLRequest
                
                Alamofire.request(request).responseData(completionHandler: { (response) in
                  switch response.result {
                  case .success(let data):
                    do {
                      let xml = try HTMLDocument(data: data)
                      
                      guard let trackElement = xml.firstChild(xpath: "//table/tbody/tr[@adam-id='\(podcastID)']"),
                        let streamURL = trackElement.attr("audio-preview-url"),
                        let durationString = trackElement.attr("preview-duration"),
                        let duration = Float(durationString),
                        let imageURL = xml.firstChild(css: "#left-stack img.artwork")?.attr("src-swap-high-dpi"),
                        let artist = xml.firstChild(css: "#title h1")?.stringValue,
                        let title = trackElement.attr("preview-title") else {
                          return
                      }
                      
                      let context = PersistentContainer.shared.viewContext
                      let entity = NSEntityDescription.entity(forEntityName: "Podcast", in: context)!
                      let podcast = Podcast(entity: entity, insertInto: context)
                      
                      podcast.downloadURL = streamURL
                      podcast.episodeTitle = title
                      podcast.podcastTitle = artist
//                      podcast.duration = duration/1000
                      
                      print(podcast)
                    } catch let error as NSError {
                      print(error)
                    }
                    
                  case .failure(let error):
                    print(error)
                  }
                })
              } else {
                try! PodcastFeedFinder.sharedFinder.getMediaURLForPodcastLink(url, completion: { result in
                  print(result)
                  self.done()
                })
              }
            }
          })
        }
      }
    }
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  @IBAction func done() {
    // Return any edited content to the host app.
    // This template doesn't do anything, so we just echo the passed in items.
    self.extensionContext!.completeRequest(returningItems: self.extensionContext!.inputItems, completionHandler: nil)
  }
  
}
