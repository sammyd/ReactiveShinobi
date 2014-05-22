# ReactiveShinobi - Using ReactiveCocoa with ShinobiCharts

### Introduction

[ReactiveCocoa](https://github.com/ReactiveCocoa/ReactiveCocoa) is a very
popular framework which allows developers of iOS and OSX applications to write
in a manner inspired by the [Functional Reactive Programming](http://en.wikipedia.org/wiki/Functional_reactive_programming)
paradigm. It's modeled on [Reactive Extensions](https://rx.codeplex.com/) from
the .net world, and rather than using mutable variables, data is presented as a
signal, which represents a stream of the current and future events. These
signals can be manipulated and are extremely helpful for handling asynchronous
events. ShinobiControls' CTO, [Colin Eberhardt](https://twitter.com/ColinEberhardt), has
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
  result at the end of the pipeline, each time an event is received.
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

As you know, data is provided to a ShinobiChart via the `SChartDatasource`
delegate - which consists of 4 required methods. Since this application consists
of a stream of data which should result in data points being appended to the
chart then it makes sense to have a __LiveDatasource__ class, which has the
following interface:

    @interface SCLiveDataSource : NSObject
    - (instancetype)initWithChart:(ShinobiChart *)chart;
    - (void)appendValue:(NSNumber *)value;
    @end

When a `SCLiveDataSource` is constructed, then you need to provide a chart to
which the data sent to `appendValue:` is appended. This datasource object is
going to be pretty generic - it simply plots the given numeric value on the
y-axis, with the time it was appended on the x-axis.

The class extension adds a property to store the data points, and one to keep a
reference to the chart:

    @interface SCLiveDataSource () <SChartDatasource>

    @property (nonatomic, strong) ShinobiChart *chart;
    @property (nonatomic, strong) NSMutableArray *dataPoints;

    @end

Since the `SCLiveDataSource` class adopts the `SChartDataSource` protocol, there
are 4 methods which need implementing - all of which are fairly simple:

    #pragma mark - SChartDataSource methods
    - (NSInteger)numberOfSeriesInSChart:(ShinobiChart *)chart
    {
        return 1;
    }

    - (SChartSeries *)sChart:(ShinobiChart *)chart seriesAtIndex:(NSInteger)index
    {
        return [SChartLineSeries new];
    }

    - (NSInteger)sChart:(ShinobiChart *)chart numberOfDataPointsForSeriesAtIndex:(NSInteger)seriesIndex
    {
        return [self.dataPoints count];
    }

    - (id<SChartData>)sChart:(ShinobiChart *)chart dataPointAtIndex:(NSInteger)dataIndex forSeriesAtIndex:(NSInteger)seriesIndex
    {
        return self.dataPoints[dataIndex];
    }

The implementations of these methods simply return a single line series, whose
datapoints are all stored in the `dataPoints` array.

The final aspect of this datasource class is the `appendValue:` method:

    - (void)appendValue:(NSNumber *)value
    {
        SChartDataPoint *dp = [SChartDataPoint new];
        dp.xValue = [NSDate date];
        dp.yValue = value;
        [self.dataPoints addObject:dp];
        [self.chart appendNumberOfDataPoints:1 toEndOfSeriesAtIndex:0];
        [self.chart redrawChart];
    }

This method takes an `NSNumber` and sets it as the y-value of a newly created
datapoint, whose x-value is the current time. The
`appendNumberOfDataPoints:toEndOfSeriesAtIndex:` method tells the chart that there
a new data point is available, and should be drawn at the end of the series.
This is part of the streaming API, and allows new data to be added to a chart
without having to reload all the data.

That completes the generic live data data source - and it's ready to be wired
in to a ReactiveCocoa pipeline.


#### Using the live-streaming datasource with ReactiveCocoa

The sample project has a `ShinobiChart` set up in the storyboard, so there are a
few additional things which need configuring in the `viewDidLoad` method of
`SCViewController`:

    SChartDateTimeAxis *xAxis = [SChartDateTimeAxis new];
    SChartNumberRange *range = [[SChartNumberRange alloc] initWithMinimum:@0 andMaximum:@5];
    SChartNumberAxis *yAxis = [[SChartNumberAxis alloc] initWithRange:range];
    self.chart.xAxis = xAxis;
    self.chart.yAxis = yAxis;

These simple lines just set the different axis types to match the data types that
will be plotted.

The class extension defines a property to keep hold of the data source, so the
following will create one:

    self.datasource = [[SCLiveDataSource alloc] initWithChart:self.chart];

The chart is going to display the current instantaneous Wikipedia edit-rate - i.e.
the how many message have been received over the websocket in a given time. For
the purposes of this, the sample rate will be 5 seconds. That means to estimate
the edit rate, you're going to count how many messages are received in a 5 second
period and then divide that by 5. This is where ReactiveCocoa pipelines come into
their own - implementing this functionality without RAC would involve creating
an `NSTimer` and a counter and implementing a delegate or callback. In RAC it is
just 10 lines long:

    [[[[[self.wsConnector.messages                      // 1
      bufferWithTime:5.0 onScheduler:scheduler]         // 2
      map:^id(RACTuple *value) {                        // 3
          return @([value count] / 5.0);
      }]
      deliverOn:[RACScheduler mainThreadScheduler]]     // 4
      logNext]                                          // 5
      subscribeNext:^(id x) {                           // 6
         [self.datasource appendValue:x];
      }];

Each of the lines of this pipeline is discussed below:

1. In the same you did with the original pipeline, your going to subscribe to
the `messages` `RACSignal` on the web socket connector. You can add as many
different pipelines to this signal - which is one of the things that makes RAC
incredibly powerful.
2. The `bufferWithTime:onScheduler:` method will collect the values from the
signal for a period of 5 seconds, and then deliver the colletion as a `RACTuple`
to the pipeline. This single method provides the majority of the functionality
required to perform the rate calculation.
3. You've seen the `map` method before - here it's being used to calculate the
rate from the `RACTuple` - simply the size of the `RACTuple` over the length
of the temporal window - in this case 5 seconds.
4. `deliverOn:` is again used to ensure that the result is returns on the main
thread, since there is goin to be some UI updating again.
5. `logNext` is a simple utility which will log all of the `next` events emitted
by the signal. Its primary use is for debugging.
6. `subscribeNext:` specifies that the supplied block will be executed each time
a `next` event (as opposed to a `completed` or `error` event). This block is taking
the `NSNumber` created by the previous `map` method and passing it to the
datasource with the `appendValue:` message.

If you run the app up now you'll see that along with the names of the edited
articles, you now have a chart to which a new data point is added every 5 seconds.
The values plotted represent the current instantaneous edit rate.

This is starting to demonstrate the real power of RAC - you now have 2 distinct
pipelines which perform completely different processing on the same data source.
Without RAC this would likely involve ballooning methods, with the different
functionalities all inter-mixed. With RAC, the pipelines are succinct, easy-to-read,
and represent an independent chunk of functionality.


### Bonus: New user annotations

Once you've realised the power of these RAC pipelines, it becomes quite a lot of
fun to build them. In this section you're going to add annotations to the chart
to represent new-user signup events - represented by the event type `newuser`.

Have a think about what the pipeline might need to do before you read on?
Remember that you're getting a stream of events, only some of which you are
interested in. Then you want to transform each of those into an annotation -
an `SChartAnnotation` in fact. Read on to see the completed pipeline...


    [[[[self.wsConnector.messages                                                    // 1
    filter:^BOOL(NSDictionary *value) {                                              // 2
        return [value[@"type"] isEqualToString:@"newuser"];
    }]
    map:^id(NSDictionary *value) {                                                   // 3
        UIColor *translucentRed = [[UIColor redColor] colorWithAlphaComponent:0.5];
        return [SChartAnnotation verticalLineAtPosition:value[@"time"]
                                              withXAxis:self.chart.xAxis
                                               andYAxis:self.chart.yAxis
                                              withWidth:2.0
                                              withColor:translucentRed];
    }]
    deliverOn:[RACScheduler mainThreadScheduler]]                                    // 4
    subscribeNext:^(SChartAnnotation *annotation) {                                  // 5
        [self.chart addAnnotation:annotation];
        [self.chart redrawChart];
    }];

1. Again, you want to subscribe to the same messages `RACSignal`.
2. The `filter` operation is used to drop all the events which aren't of type
`newuser`.
3. The `NSDictionary` events are mapped to `SChartAnnotation`. This particular
one is a vertical line, anchored to the `time` attribute of the event on the y-axis.
This means that as the chart scrolls and rescales, the annotation will remain in
the correct data location.
4. Since the UI is being updated, the delivery needs to be marshalled onto the
main thread.
5. Finally, the subscription adds the annotation to the chart with `addAnnotation:`
and tells the chart that it should redraw itself.

Run the app up now and after a while you'll start seeing red vertical lines
appearing - representing new users signing up.

PICTURE HERE

So now you've created 3 pipelines, each with completely different functionality,
but each really concise and self-contained. This is really rather wonderful.


### Conclusion

ReactiveCocoa involves thinking about your app design in quite a different way -
in terms of a flow of data or a stream of events as opposed to the traditional
event-handling approach. This change in paradigm can appear a little daunting
at first - especially as there is a entire vocabulary of unfamiliar terms to
learn, however I hope you'll agree that this post has demonstrated quite how
powerful this approach can be.

Once you have something which is capable of generating events (many of which are
already exist as part of RAC), then the ability to build the processing pipelines
is both extremely powerful, and also quite a lot of fun.

Streaming data is particularly applicable to appending data to ShinobiCharts, but
there are other scenarios in which this approach would work nicely with
ShinobiControls products. I encourage you to have a try at creating your own
pipeline within the demo app you've built today, and then to think about using
RAC in your own apps. It needn't be all or nothing - you could use RAC for just
a small part of you app at first, and as you become more comfortable with it you
might find that you're finding more and more uses for it.

As ever, the code for this sample project is available on Github at
[github.com/shinobicontrols/ReactiveShinobi](https://github.com/shinobicontrols/ReactiveShinobi).
Go ahead and clone the repo and give it a try, and if you have any questions,
queries or problems, feel free to give us a shout!


sam
