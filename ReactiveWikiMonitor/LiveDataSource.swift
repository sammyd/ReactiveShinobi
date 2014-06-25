//
//  LiveDataSource.swift
//  ReactiveWikiMonitor
//
//  Created by Sam Davies on 25/06/2014.
//  Copyright (c) 2014 Shinobi Controls. All rights reserved.
//

import Foundation

class LiveDataSource: NSObject, SChartDatasource {
  
  var chart: ShinobiChart
  var dataPoints = SChartDataPoint[]()
  
  init(chart: ShinobiChart) {
    self.chart = chart
    
    super.init()
    
    self.chart.datasource = self
  }
  
  func appendValue(value: NSNumber) {
    let dp = SChartDataPoint()
    dp.xValue = NSDate()
    dp.yValue = value
    dataPoints.append(dp)
    chart.appendNumberOfDataPoints(1, toEndOfSeriesAtIndex: 0)
    chart.redrawChart()
  }
  
  // <SChartDatasource>
  func numberOfSeriesInSChart(chart: ShinobiChart!) -> Int {
    return 1
  }
  
  func sChart(chart: ShinobiChart!, seriesAtIndex index: Int) -> SChartSeries! {
    return SChartLineSeries()
  }
  
  func sChart(chart: ShinobiChart!, numberOfDataPointsForSeriesAtIndex seriesIndex: Int) -> Int {
    return dataPoints.count
  }
  
  func sChart(chart: ShinobiChart!, dataPointAtIndex dataIndex: Int, forSeriesAtIndex seriesIndex: Int) -> SChartData! {
    return dataPoints[dataIndex]
  }
}