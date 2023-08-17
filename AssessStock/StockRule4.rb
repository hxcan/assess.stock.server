#!/usr/bin/env ruby
# frozen_string_literal: true

# buy at absolute price.
class StockRule4 < StockRule
  attr_accessor :price
  
  # Get the buy in price suggested by this rule.
  def getBuyInPrice( dateDataList, currentCandidateBuyInDateINdex )
    idealBuyInPrice = normalizePriceFloor(@price) # Calculate the ideal buy in price.
  end # getBuyInPrice( dateDataList, currentCandidateBuyInDateINdex ) # Get the buy in price suggested by this rule.
  
  def initialize
    @price = 0 # price.
    @ruleType = RuleType::Buy # Buy type.
  end # def initialize
end # class StockRule2 < StockRule
