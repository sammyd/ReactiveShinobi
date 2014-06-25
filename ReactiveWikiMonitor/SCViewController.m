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


#import "SCViewController.h"
#import <ShinobiCharts/ShinobiChart.h>
#import "SCWebSocketConnector.h"
#import "ReactiveWikiMonitor-Swift.h"

@interface SCViewController ()

@property (nonatomic, strong) LiveDataSource *datasource;
@property (nonatomic, strong) SCWebSocketConnector *wsConnector;

@end

@implementation SCViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    self.chart.title = @"Wikipedia Live Updates";
    
    SChartDateTimeAxis *xAxis = [SChartDateTimeAxis new];
    SChartNumberAxis *yAxis = [[SChartNumberAxis alloc] initWithRange:[[SChartNumberRange alloc] initWithMinimum:@0 andMaximum:@5]];
    yAxis.title = @"Edit Rate (edits/second)";
    self.chart.xAxis = xAxis;
    self.chart.yAxis = yAxis;
    
    self.chart.licenseKey = @"";
    
    self.datasource = [[LiveDataSource alloc] initWithChart:self.chart];
    
    
    RACScheduler *scheduler = [RACScheduler schedulerWithPriority:RACSchedulerPriorityDefault
                                                             name:@"com.shinobicontrols.ReactiveWikiMonitor.bufferScheduler"];
    
    self.wsConnector = [[SCWebSocketConnector alloc] initWithURL:[NSURL URLWithString:@"ws://wiki-update-sockets.herokuapp.com/"]];
    [self.wsConnector start];
    
    // Calculate the rate
    [[[[[self.wsConnector.messages
      bufferWithTime:5.0 onScheduler:scheduler]
      map:^id(RACTuple *value) {
          return @([value count] / 5.0);
      }]
      deliverOn:[RACScheduler mainThreadScheduler]]
      logNext]
      subscribeNext:^(id x) {
         [self.datasource appendValue:x];
      }];
    
    // Extract the edited content
    RAC(self.tickerLabel, text) =
     [[[self.wsConnector.messages
     filter:^BOOL(NSDictionary *value) {
         return [value[@"type"] isEqualToString:@"unspecified"];
     }]
     map:^id(NSDictionary *value) {
         return value[@"content"];
     }]
     deliverOn:[RACScheduler mainThreadScheduler]];
    
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
