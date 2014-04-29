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
    NSError *error;
    NSDictionary *deserialised = [self parseWikipediaUpdateMessage:message error:&error];
    if(error) {
        NSLog(@"Error parsing JSON String: %@", error);
        return;
    }
    
    [self.scheduler schedule:^{
        [self.messagesSubj sendNext:deserialised];
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

#pragma mark - Utility Methods
- (NSDictionary *)parseWikipediaUpdateMessage:(NSString *)message error:(NSError **)error
{
    // Extract the JSON
    NSData *messageData = [message dataUsingEncoding:NSUTF8StringEncoding];
    id deserialised = [NSJSONSerialization JSONObjectWithData:messageData
                                                      options:0
                                                        error:error];
    if(*error) {
        return nil;
    }
    
    // Want to convert the time string to an NSDate
    static NSDateFormatter *df = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        df = [[NSDateFormatter alloc] init];
        [df setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSZ"];
    });
    
    // Create a new dictionary with the appropriate values in
    NSMutableDictionary *parsed = [NSMutableDictionary new];
    parsed[@"type"] = [deserialised objectForKey:@"type"];
    parsed[@"time"] = [df dateFromString:[deserialised objectForKey:@"time"]];
    
    return [parsed copy];
}

@end
