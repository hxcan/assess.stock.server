#!/usr/bin/env ruby
# frozen_string_literal: true

# buy at low rate.
class StockRule5 < StockRule
  attr_accessor :lowRate
  
  # Get the buy in price suggested by this rule.
  def getBuyInPrice( dateDataList, currentCandidateBuyInDateINdex )
    priceMapLastDate=dateDataList[currentCandidateBuyInDateINdex+1]['priceMap'] #获取上一天的价格映射
    priceHigh=priceMapLastDate['low'] # Get the lowest price in the last transaction day.

    idealBuyInPrice=normalizePriceFloor(priceHigh * @lowRate) # 计算出理想的买入价
    
    idealBuyInPrice
  end # getBuyInPrice( dateDataList, currentCandidateBuyInDateINdex ) # Get the buy in price suggested by this rule.
  
  def initialize
    @lowRate = 0 # low rate.
    @ruleType = RuleType::Buy # Buy type.
  end # def initialize
end # class StockRule2 < StockRule
