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

### Creating a WebSocket RACSignal

### A Live-data streaming SChartDatasource



### Conclusion