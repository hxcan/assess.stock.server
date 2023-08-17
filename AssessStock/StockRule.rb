#!/usr/bin/env ruby
# frozen_string_literal: true

class StockRule
  attr_reader :ruleType # Rule type, buy or sell.
  
  def initialize
    @ruleType = nil # rule type.
  end
  
  #将价格调整成标准价格，向下调整
  def normalizePriceFloor(randomPrice)
    result=((randomPrice*100).floor)/100.0
  end #def normalizePriceFloor(randomPrice) #将价格调整成标准价格，向下调整

  #将价格调整成标准价格，向上调整
  def normalizePriceCeil(sellprice) 
    result=((sellprice*100).ceil)/100.0
  end # normalizePriceCeil(sellprice) #将价格调整成标准价格，向上调整

  # Get the buy in price suggested by this rule.
  def getBuyInPrice( dateDataList, currentCandidateBuyInDateINdex )
    nil # this rule does not give buy in price suggestions.
  end # getBuyInPrice( dateDataList, currentCandidateBuyInDateINdex ) # Get the buy in price suggested by this rule.

  # Get the sell out price suggested by this rule.
  def getSellOutPrice( dateDataList, currentCandidateSellDateIndx )
    nil # this rule does not give sell out price suggestions.
  end # getSellOutPrice( dateDataList, currentCandidateSellDateIndx ) # Get the sell out price suggested by this rule.
end #class StockAssessor
