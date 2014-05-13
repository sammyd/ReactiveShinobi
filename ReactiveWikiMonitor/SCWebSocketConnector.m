/*
 *  Copyright 2014 Scott Logic Ltd
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */


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
    NSMutableDictionary *parsed = [NSMutableDictionary dictionaryWithDictionary:deserialised];
    parsed[@"time"] = [df dateFromString:[deserialised objectForKey:@"time"]];
    
    return [parsed copy];
}

@end
