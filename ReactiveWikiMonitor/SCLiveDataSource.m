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
