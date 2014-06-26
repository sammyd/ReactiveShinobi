//
//  WebSocketConnector.swift
//  ReactiveWikiMonitor
//
//  Created by Sam Davies on 25/06/2014.
//  Copyright (c) 2014 Shinobi Controls. All rights reserved.
//

import Foundation

class WebSocketConnector: NSObject, SRWebSocketDelegate {
  
  // Public properties
  var messages: RACSignal { return messagesSubject }
  
  // Private properties
  var webSocket: SRWebSocket
  var scheduler: RACScheduler
  var messagesSubject: RACSubject
  class var dateFormatter : NSDateFormatter {
  struct Static {
    static let instance : NSDateFormatter = NSDateFormatter()
    }
    return Static.instance
  }
  
  // Object lifecycle
  init(url: NSURL) {
    // Prepare the properties
    webSocket = SRWebSocket(URL: url)
    scheduler = RACScheduler(priority: RACSchedulerPriorityDefault,
                             name: "com.shinobicontrols.ReactiveWikiMonitor.SCWebSocketConnector")
    messagesSubject = RACSubject()
    
    // Prepare the date formatter
    WebSocketConnector.dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
    
    // Init the superclass
    super.init()
    
    // And now we can use self
    webSocket.delegate = self
  }
  
  deinit {
    messagesSubject.sendCompleted()
  }
  
  // API Methods
  func start() {
    webSocket.open()
  }
  
  func stop() {
    webSocket.close()
  }
  
  // <SRWebSocketDelegate>
  func webSocket(webSocket: SRWebSocket!, didReceiveMessage message: AnyObject!) {
    if let messageString = message as? String {
      var error: NSError?
      let deserialised = parseWikipediaUpdateMessage(messageString, error: &error)
      if error {
        println("There was an error parsing the JSON: \(error.description)")
        return
      }
      
      scheduler.schedule { self.messagesSubject.sendNext(deserialised) }
    }
  }
  
  func webSocket(webSocket: SRWebSocket!, didFailWithError error: NSError!) {
    scheduler.schedule { self.messagesSubject.sendError(error) }
  }
  
  func webSocket(webSocket: SRWebSocket!, didCloseWithCode code: Int!, reason:String!, wasClean:Bool!) {
    scheduler.schedule { self.messagesSubject.sendCompleted() }
  }
  
  
  // Private utility methods
  func parseWikipediaUpdateMessage(message: String, error: NSErrorPointer) -> NSDictionary? {
    // Extract the JSON
    let messageData = message.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)
    let deserialised: AnyObject! = NSJSONSerialization.JSONObjectWithData(messageData, options: nil, error: error)
    
    if error.memory {
      return nil
    }
    
    // Parse the date string
    if let deserialisedDict = deserialised as? NSDictionary  {
      var parsed = NSMutableDictionary(dictionary: deserialisedDict)
      parsed["time"] = "hello"
      parsed["time"] = WebSocketConnector.dateFormatter.dateFromString(deserialisedDict["time"] as String)
      return parsed.copy() as? NSDictionary
    }
    
    // Otherwise we fail
    return nil
  }
  
}