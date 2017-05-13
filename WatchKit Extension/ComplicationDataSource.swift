//
//  ComplicationDataSource.swift
//  Master Caster
//
//  Created by Miles Hollingsworth on 5/10/17.
//  Copyright © 2017 Miles Hollingsworth. All rights reserved.
//

import WatchKit

class ComplicationDataSource: NSObject, CLKComplicationDataSource {
  func getSupportedTimeTravelDirections(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimeTravelDirections) -> Void) {
    handler([])
  }
  
  func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
    let entry: CLKComplicationTimelineEntry
    let template = CLKComplicationTemplateModularSmallSimpleImage()
    
    //Doesnt work as of 10.3.1
//    template.tintColor = UIColor(red: 102.0/255.0, green: 0, blue: 218.0/255.0, alpha: 1)
    
    switch complication.family {
    case .modularSmall:
      template.imageProvider = CLKImageProvider(onePieceImage: UIImage(named: "Complication/Modular")!)
    case .circularSmall:
      template.imageProvider = CLKImageProvider(onePieceImage: UIImage(named: "Complication/Circular")!)
      
    default:
      fatalError("Unhandled complication size")
    }

    entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
    handler(entry)
  }
}
