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
@property (nonatomic, strong) RACScheduler *scheduler;
@property (nonatomic, strong) RACSubject *messagesSubj;

@end

@implementation SCWebSocketConnector

- (instancetype)initWithURL:(NSURL *)url
{
    self = [super init];
    if(self) {
        self.webSocket = [[SRWebSocket alloc] initWithURL:url];
        self.webSocket.delegate = self;
        
        // Prepare ReactiveCocoa
        self.scheduler = [RACScheduler schedulerWithPriority:RACSchedulerPriorityDefault name:@"com.shinobicontrols.ReactiveWikiMonitor.SCWebSocketConnector"];
        self.messagesSubj = [RACSubject subject];
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

- (RACSignal *)messages
{
    return self.messagesSubj;
}

- (void)dealloc
{
    [self.messagesSubj sendCompleted];
}

#pragma mark - SRWebSocketDelegate Methods
- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message
{
    [self.scheduler schedule:^{
        [self.messagesSubj sendNext:message];
    }];
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
    [self.scheduler schedule:^{
        [self.messagesSubj sendError:error];
    }];
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    [self.scheduler schedule:^{
        [self.messagesSubj sendCompleted];
    }];
}

@end
