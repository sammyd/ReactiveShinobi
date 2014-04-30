//
//  SCViewController.m
//  ReactiveWikiMonitor
//
//  Created by Sam Davies on 29/04/2014.
//  Copyright (c) 2014 Shinobi Controls. All rights reserved.
//

#import "SCViewController.h"
#import <ShinobiCharts/ShinobiChart.h>
#import "SCLiveDataSource.h"
#import "SCWebSocketConnector.h"

@interface SCViewController ()

@property (nonatomic, strong) SCLiveDataSource *datasource;
@property (nonatomic, strong) SCWebSocketConnector *wsConnector;

@end

@implementation SCViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    SChartDateTimeAxis *xAxis = [SChartDateTimeAxis new];
    SChartNumberAxis *yAxis = [[SChartNumberAxis alloc] initWithRange:[[SChartNumberRange alloc] initWithMinimum:@0 andMaximum:@5]];
    self.chart.xAxis = xAxis;
    self.chart.yAxis = yAxis;
    
    self.chart.licenseKey = @"";
    
    self.datasource = [[SCLiveDataSource alloc] initWithChart:self.chart];
    [self.view addSubview:self.chart];
    
    
    
    RACScheduler *scheduler = [RACScheduler schedulerWithPriority:RACSchedulerPriorityDefault
                                                             name:@"com.shinobicontrols.ReactiveWikiMonitor.bufferScheduler"];
    
    self.wsConnector = [[SCWebSocketConnector alloc] initWithURL:[NSURL URLWithString:@"ws://wiki-update-sockets.herokuapp.com/"]];
    [self.wsConnector start];
    
    // Calculate the rate
    [[[[self.wsConnector.messages
      bufferWithTime:5.0 onScheduler:scheduler]
      map:^id(RACTuple *value) {
          return @([value count] / 5.0);
      }]
      deliverOn:[RACScheduler mainThreadScheduler]]
      subscribeNext:^(id x) {
         NSLog(@"Rate: %@", x);
         [self.datasource appendValue:x];
      }];
    
    // Extract the edited content
    [[[[self.wsConnector.messages
     filter:^BOOL(NSDictionary *value) {
         return [value[@"type"] isEqualToString:@"unspecified"];
     }]
     map:^id(NSDictionary *value) {
         return value[@"content"];
     }]
     deliverOn:[RACScheduler mainThreadScheduler]]
     subscribeNext:^(NSString *x) {
        self.tickerLabel.text = x;
     }];
    
    // Find the new user events
    [[[[self.wsConnector.messages
    filter:^BOOL(NSDictionary *value) {
        return [value[@"type"] isEqualToString:@"newuser"];
    }]
    map:^id(NSDictionary *value) {
        return [SChartAnnotation verticalLineAtPosition:value[@"time"]
                                              withXAxis:self.chart.xAxis
                                               andYAxis:self.chart.yAxis
                                              withWidth:2.0
                                              withColor:[[UIColor redColor] colorWithAlphaComponent:0.5]];
    }]
    deliverOn:[RACScheduler mainThreadScheduler]]
    subscribeNext:^(SChartAnnotation *annotation) {
        [self.chart addAnnotation:annotation];
        [self.chart redrawChart];
    }];
    
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskLandscape;
}

@end
