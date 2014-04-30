//
//  SCLiveDataSource.h
//  ReactiveWikiMonitor
//
//  Created by Sam Davies on 30/04/2014.
//  Copyright (c) 2014 Shinobi Controls. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ShinobiCharts/ShinobiChart.h>

@interface SCLiveDataSource : NSObject

- (instancetype)initWithChart:(ShinobiChart *)chart;
- (void)appendValue:(NSNumber *)value;

@end
