//
//  SCWebSocketConnector.m
//  ReactiveWikiMonitor
//
//  Created by Sam Davies on 29/04/2014.
//  Copyright (c) 2014 Shinobi Controls. All rights reserved.
//

#import "SCWebSocketConnector.h"
#import <SocketRocket/SRWebSocket.h>

@interface SCWebSocketConnector () <SRWebSocketDelegate>

@property (nonatomic, strong) SRWebSocket *webSocket;

@end

@implementation SCWebSocketConnector

- (instancetype)initWithURL:(NSURL *)url
{
    self = [super init];
    if(self) {
        self.webSocket = [[SRWebSocket alloc] initWithURL:url];
        self.webSocket.delegate = self;
    }
    return self;
}

- (void)start
{
    [self.webSocket open];
}

- (void)stop
{
    [self.webSocket close];
}

#pragma mark - SRWebSocketDelegate Methods
- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message
{
    NSLog(@"%@", message);
}

@end
