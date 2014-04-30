//
//  SCLiveDataSource.m
//  ReactiveWikiMonitor
//
//  Created by Sam Davies on 30/04/2014.
//  Copyright (c) 2014 Shinobi Controls. All rights reserved.
//

#import "SCLiveDataSource.h"

@interface SCLiveDataSource () <SChartDatasource>

@property (nonatomic, strong) ShinobiChart *chart;
@property (nonatomic, strong) NSMutableArray *dataPoints;

@end


@implementation SCLiveDataSource

- (instancetype)initWithChart:(ShinobiChart *)chart
{
    self = [super init];
    if(self) {
        self.chart = chart;
        self.chart.datasource = self;
        self.dataPoints = [NSMutableArray new];
    }
    return self;
}

- (void)appendValue:(NSNumber *)value
{
    SChartDataPoint *dp = [SChartDataPoint new];
    dp.xValue = [NSDate date];
    dp.yValue = value;
    [self.dataPoints addObject:dp];
    [self.chart appendNumberOfDataPoints:1 toEndOfSeriesAtIndex:0];
    [self.chart redrawChart];
}

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
@end
