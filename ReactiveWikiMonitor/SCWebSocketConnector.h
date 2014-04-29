//
//  SCWebSocketConnector.h
//  ReactiveWikiMonitor
//
//  Created by Sam Davies on 29/04/2014.
//  Copyright (c) 2014 Shinobi Controls. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ReactiveCocoa/ReactiveCocoa.h>

@interface SCWebSocketConnector : NSObject

- (instancetype)initWithURL:(NSURL *)url;

@property (nonatomic, strong, readonly) RACSignal *messages;

- (void)start;
- (void)stop;

@end
