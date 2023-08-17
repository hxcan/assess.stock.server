#!/usr/bin/env ruby
# frozen_string_literal: true

# sell at high rate.
class StockRule1 < StockRule
  attr_accessor :highRate

  # Get the sell out price suggested by this rule.
  def getSellOutPrice( dateDataList, currentCandidateSellDateIndx )
    priceMapLastDate=dateDataList[currentCandidateSellDateIndx+1]['priceMap'] #获取上一天的价格映射

    priceHigh = @priceHighCache[currentCandidateSellDateIndx] # get price high from cache.
    
    unless priceHigh # not exist in cache
      priceHigh=priceMapLastDate['close'] #获取上一天收盘价
      
      @priceHighCache[currentCandidateSellDateIndx] = priceHigh # remember in cache.
    end # unless priceHigh # not exist in cache
    

    idealBuyInPrice=normalizePriceCeil(priceHigh * @highRate) # 计算出理想的卖出价

    idealBuyInPrice
  end # getSellOutPrice( dateDataList, currentCandidateSellDateIndx ) # Get the sell out price suggested by this rule.

  def initialize
    @ruleType = RuleType::Sell # Sell type.
    @highRate = 0 # high rate
    @priceHighCache = {} # price high cache.
  end
end # class StockRule1 < StockRule
