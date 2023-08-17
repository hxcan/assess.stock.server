#!/usr/bin/env ruby
# frozen_string_literal: true

# buy at low rate. When in the last a few days, the rate of low price to high price is lower than or equals to some rate threshold.
class StockRule3 < StockRule
  attr_accessor :lowRate
  attr_accessor :rateThreshold
  attr_accessor :checkDayAmount

  # Get the buy in price suggested by this rule.
  def getBuyInPrice( dateDataList, currentCandidateBuyInDateINdex )
    # priceCheckDateIndexRange = (currentCandidateBuyInDateINdex+1)..(currentCandidateBuyInDateINdex + @checkDayAmount) # Get the check date index range.

    lowPriceInRange = Float::INFINITY # low price in range.
    highPriceInRange = -Float::INFINITY # high price in range.

    idealBuyInPrice = nil # The calculated buy in price.

    if (dateDataList.size > currentCandidateBuyInDateINdex + @checkDayAmount) # There is enough data for this date index.
      dateIndex = currentCandidateBuyInDateINdex+1
      while dateIndex <= currentCandidateBuyInDateINdex + @checkDayAmount
      # priceCheckDateIndexRange.each do |dateIndex| # check index one by one
        
        priceMap = @priceMapCache[dateIndex] # get it from cache.
        
        unless priceMap # not exist in cache
          priceMap=dateDataList[dateIndex]['priceMap'] # 获取价格映射
          
          @priceMapCache[dateIndex] = priceMap # remember it in cache.
        end # unless priceMap # not exist in cache
        

        priceMin = @priceMinCache[dateIndex] # get it from cache

        unless priceMin # not exist in cache
          priceMin=priceMap['low'] #获取最低价

          @priceMinCache[dateIndex]=priceMin # remember it in cache.
        end # unless priceMin # not exist in cache
        

        priceMax = priceMap['high'] # get high price.

        lowPriceInRange = [lowPriceInRange, priceMin].min # get low price in range.
        highPriceInRange = [highPriceInRange, priceMax].max # get high price in range.
        
        dateIndex += 1
      end # priceCheckDateIndexRange.each do |dateIndex| # check index one by one
      
      priceRateLowHigh = lowPriceInRange / highPriceInRange # Calculate the actual price rate of low price to high price.
      
      if (priceRateLowHigh <= @rateThreshold) # lower than or equals to rate threshold. Should buy.
        priceMapLastDate=dateDataList[currentCandidateBuyInDateINdex+1]['priceMap'] #获取上一天的价格映射
        priceHigh=priceMapLastDate['close'] #获取上一天收盘价

        idealBuyInPrice = normalizePriceFloor(priceHigh * @lowRate) # 计算出理想的买入价
      end # if (priceRateLowHigh <= @rateThreshold) # lower than or equals to rate threshold. Should buy.
    end # if (dateDataList.size > currentCandidateBuyInDateINdex + @checkDayAmount) # There is enough data for this date index.

    idealBuyInPrice
  end # getBuyInPrice( dateDataList, currentCandidateBuyInDateINdex ) # Get the buy in price suggested by this rule.

  def initialize
    @lowRate = 0 # low rate.
    @rateThreshold = 0 # rate threshold
    @checkDayAmount = 0 # check day amount.
    @ruleType = RuleType::Buy # Buy type.
    @priceMinCache = {} # price min cache
    @priceMapCache = {} # price map cache
  end # def initialize
end # class StockRule3 < StockRule
