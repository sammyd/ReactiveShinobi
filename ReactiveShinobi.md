# ReactiveShinobi - Using ReactiveCocoa with ShinobiCharts

### Introduction

[ReactiveCocoa](https://github.com/ReactiveCocoa/ReactiveCocoa) is a very
popular framework which allows developers of iOS and OSX applications to write
using the [Functional Reactive Programming](http://en.wikipedia.org/wiki/Functional_reactive_programming)
paradigm. It's modeled on [Reactive Extensions](https://rx.codeplex.com/) from
the .net world, and rather than using mutable variables, data is presented as a
signal, which represents a stream of the current and future events. These
signals can be manipulated and are extremely helpful for handling asynchronous
events. Our CTO, [Colin Eberhardt](https://twitter.com/ColinEberhardt), has
recently written the [definitive introduction to ReactiveCocoa](http://www.raywenderlich.com/62699/reactivecocoa-tutorial-pt1)
on [raywenderlich.com](http://www.raywenderlich.com/) - and this is well worth
a read if the concept is new to you.

ReactiveCocoa is often focused on one-off async events (such as a network
request) or interacting with the GUI, but network push events (such as those
introduced with WebSockets) present an excellent opportunity for the advanced
stream operations. In this post we'll look at how to use SocketRocket with
ReactiveCocoa to generate a stream of events from a WebSocket.

One oft-overlooked feature of ShinobiCharts is the ability to append datapoints
without having to completely reload the data - i.e. live data charts. This
process matches really nicely with a data stream - so this article will look at
creating a data source which can live-update a chart, and wire it into
ReactiveCocoa.

The project consists of an app which connects to a WebSocket which streams live
updates from wikipedia. The current edit-rate is calculated and displayed on a
chart, along with specific events and the name of the articles recently edited.

This post is not an introduction to ReactiveCocoa or ShinobiCharts. If you'd
like to know more about ReactiveCocoa then check out Colin's [introduction](http://www.raywenderlich.com/62699/reactivecocoa-tutorial-pt1),
and for more info on ShinobiCharts, the
[user guide](http://www.shinobicontrols.com/docs/ShinobiControls/ShinobiCharts/2.6.0/Premium/Normal/user_guide.html)
is the place to go.

All the code for this project is available on Github at
[github.com/ShinobiControls/ReactiveShinobi](https://github.com/ShinobiControls/ReactiveShinobi).
The ReactiveCocoa and SocketRocket dependencies are handled by CocoaPods, so
you'll need to run `pod install` in the project directory once you have cloned
it.


### Connecting to a WebSocket

The WebSocket specification was developed as part of HTML5, and provides for
the full-duplex delivery of a stream of messages. To connect to websocket from
inside an iOS app, the lovely people at square have open-sourced a library
called [SocketRocket](https://github.com/square/SocketRocket). It has a really
simple API, which uses delegation to return the messages received.

I've created a simple websocket you can connect to, which streams live updates
of the english version of Wikipedia - available at
`ws://wiki-update-sockets.herokuapp.com/`. The messages sent are JSON formatted
and look like the following sample responses:

    RESPONSE: {
                "type":"unspecified",
                "content":"Wikipedia talk:Articles for creation/Bonnie ZoBell",
                "time":"2014-05-15T14:45:59.175Z"
              }
    RESPONSE: {
                "type":"unspecified",
                "content":"Wikipedia:WikiProject Spam/LinkReports/blog.wifirst.fr",
                "time":"2014-05-15T14:45:59.247Z"
              }
    RESPONSE: {
                "type":"special",
                "content":"",
                "time":"2014-05-15T14:46:00.262Z"
              }
    RESPONSE: {
                "type":"unspecified",
                "content":"Manhattan Film Academy",
                "time":"2014-05-15T14:46:00.828Z"
              }

There are several different options for the `type` property - the important
thing to note is that all page edits have a `type` of `unspecified` and their
`content` property specifies the name of the page edited. You can see the
output yourself using the 'echo' service from
[websocket.org](http://www.websocket.org/echo.html), provided your browser
supports websockets.

To use SocketRocket, add the following to your Podfile and run `pod install`:

    pod 'SocketRocket'

Create a class called `SCWebSocketConnector` and add the following methods to
the interface:

    @interface SCWebSocketConnector : NSObject

    - (instancetype)initWithURL:(NSURL *)url;
    - (void)start;
    - (void)stop;

    @end

In the first instance, this class is going to connect to the websocket with
the specified URL and then just log out the messages. Later on we'll see how to
link it to ReactiveCocoa.

Implement the constructor as follows:

    - (instancetype)initWithURL:(NSURL *)url
    {
        self = [super init];
        if(self) {
            self.webSocket = [[SRWebSocket alloc] initWithURL:url];
            self.webSocket.delegate = self;
        }
        return self;
    }

Here we create an `SRWebSocket` instance with the provided URL and set the
delegate to ourself. We need to implement the following delegate methods:

    #pragma mark - SRWebSocketDelegate Methods
    - (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message
    {
        NSLog(@"Message received: %@", message);
    }

    - (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
    {
        NSLog(@"Websocket failed: %@", error);
    }

    - (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
    {
        NSLog(@"Websocket closed");
    }

The websocket can return 3 states - successful message received, socket closed
and error. The above code just logs in each instance.

The `start` and `stop` methods are simple wrappers on the websocket itself:

    - (void)start
    {
        [self.webSocket open];
    }

    - (void)stop
    {
        [self.webSocket close];
    }

You can use this class already:

    NSURL *url = [NSURL URLWithString:@"ws://wiki-update-sockets.herokuapp.com/"];
    self.wsConnector = [[SCWebSocketConnector alloc] initWithURL:url];
    [self.wsConnector start];

If you run this up then you'll see the messages being logged as they are
received from the websocket - really simple.

#### Deserializing the events

The messages returned from `SRWebSocket` are `NSString` objects containing JSON
data. Using `NSJSONSerialization` you can convert them to `NSDictionary`
objects, and then go on to parse the data string into an `NSDate`:

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

This attempts to deserialize the JSON string, and then use a static
`NSDateFormatter` to parse the date string. Update the delegate method as
follows to use this new utility method:

    - (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message
    {
        NSError *error;
        NSDictionary *deserialised = [self parseWikipediaUpdateMessage:message error:&error];
        if(error) {
            NSLog(@"Error parsing JSON String: %@", error);
            return;
        }

        NSLog(@"Message received: %@", deserialised);
    }

If you run the app up again you'll see that the log now contains `NSDictionary`
instances - which is a much more useful object to pass around.


### Creating a WebSocket RACSignal

This stream of messages from the websocket is an ideal input for a
ReactiveCocoa system. In the RAC world a `RACSignal` object is responsible for
generating events, and enables objects to subscribe to receive those events.
Therefore you're going to add a `RACSignal` property to the websocket connector
class, which will represent the stream of web socket messages.

In order to use ReactiveCocoa, add the following to your __Podfile__ and run
`pod install`:

    pod 'ReactiveCocoa', '~> 2.3'

Add the following property to the interface of `SCWebSocketConnector`:

    @property (nonatomic, strong, readonly) RACSignal *messages;

The mutable equivalent of `RACSignal` is `RACSubject`, and this allows you to
specify create the events manually. A `RACSignal` has 3 events associated with
it: __next__, __completed__ and __error__. Each of our websocket messages will
get represented by the __next__ event. Closing the websocket matches
__completed__ and an error in the websocket will spawn an __error__ event.

Create `RACSubject` and `RACScheduler` properties in the class extension:

    @interface SCWebSocketConnector () <SRWebSocketDelegate>

    @property (nonatomic, strong) SRWebSocket *webSocket;
    @property (nonatomic, strong) RACScheduler *scheduler;
    @property (nonatomic, strong) RACSubject *messagesSubj;

    @end

and add the following code to the constructor to create the scheduler and
subject:

    // Prepare ReactiveCocoa
    NSString *schedulerName = name;
    self.scheduler = [RACScheduler schedulerWithPriority:RACSchedulerPriorityDefault
                                                    name:name];
    self.messagesSubj = [RACSubject subject];

Override the `messages` getter as follows:

    - (RACSignal *)messages
    {
        return self.messagesSubj;
    }

`RACSubject` is a subclass of `RACSignal`, so this just returns the subject as
a signal.

The `SRWebSocketDelegate` methods need updating to link them up with the
`RACSubject`:

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

Sending the deserialized message is as simple as

    [self.messagesSubj sendNext:deserialised];

This will be delivered to anything which has subscribed to the `messages` signal.
The `RACScheduler` is used here as a serial operation queue - to ensure that
messages are delivered in order, and there are no threading issues.

That's pretty much it for the changes that you need to make to the web socket
connector class - in the next section you'll learn how to use it.

#### Using the new RAC-enabled websocket class

In the sample project there's a `UILabel` in the storyboard, which is linked to
the property called `tickerLabel` in `SCViewController`. You're going to see
how easy it is to update the text in that label with the most recent article to
be edited on Wikipedia.

The messages which have a `type` of `unspecified` represent the edit events, and
their `content` property is the name of the article being edited. The following
few lines of code are all that are needed to wire up the required behavior:

    RAC(self.tickerLabel, text) =                                // 1
     [[[self.wsConnector.messages                                // 2
     filter:^BOOL(NSDictionary *value) {                         // 3
         return [value[@"type"] isEqualToString:@"unspecified"];
     }]
     map:^id(NSDictionary *value) {                              // 4
         return value[@"content"];
     }]
     deliverOn:[RACScheduler mainThreadScheduler]];              // 5

The labeled lines are discussed below:
1. `RAC()` is a magic macro which sets the property named `text` (i.e. the 2nd
  argument), on the `tickerLabel` object (i.e. the 1st argument) to be the
  result at each of the
2. The `messages` property of the `SCWebSocketConnector` class is the `RACSignal`
that you created in the previous section. You're subscribing to events on this
signal.
3. The `filter` method allows you to choose which events are important - i.e.
those for whom the block returns `YES`. Here you're selecting that you only
care about the events which have a `type` of `unspecified`.
4. The `map` method applies the block to each of the events. With this block
you are extracting the `NSString` associated with the `content` key in the
`NSDictionary` which represents the event.
5. Finally, since you are updating the UI, you're requesting that the final event
be delivered (i.e. `self.tickerLabel.text = ...`) on the main thread.

This demonstrates quite how powerful ReactiveCocoa is for processing streams of
events. If you were to do this in the standard way for iOS then you'd end up with
a lot more code. The really cool thing is that this is one pipeline which
subscribes to the new websocket events, but it's trivial to build additional
pipelines and get them to subscribe too. In the next section you're going to
create another pipeline and use it to live-update a ShinobiChart.

### A Live-data streaming SChartDatasource



### Conclusion
