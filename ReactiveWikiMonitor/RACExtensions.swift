//
//  RACExtensions.swift
//  ReactiveWikiMonitor
//
//  Created by Sam Davies on 27/06/2014.
//  Copyright (c) 2014 Shinobi Controls. All rights reserved.
//

import Foundation


extension RACStream {

  func filterAs<T>(block: (T) -> Bool) -> Self {
    return filter({(value: AnyObject!) in
      if let casted = value as? T {
        return block(casted)
      }
      return false
      })
  }
  
  func mapAs<T,U: AnyObject>(block: (T) -> U) -> Self {
    return map({(value: AnyObject!) in
      if let casted = value as? T {
        return block(casted)
      }
      return nil
    })
  }
}


extension RACSignal {
  
  func subscribeNextAs<T>(block: (T) -> ()) -> RACDisposable {
    return subscribeNext({(value: AnyObject!) in
      if let casted = value as? T {
        block(casted)
      }
    })
  }
  
}