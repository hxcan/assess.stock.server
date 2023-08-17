#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json' #json解析库。
require 'csv'

class TransactionListCache
  RequestIdQueueSize = 698  # Size of request id queue.
  
  attr_accessor :eventChart
  attr_accessor :stockHistoryReporter
  
  def initialize
    @lastOperationDateINdex=0 # 上次操作过的日期下标
    @priceRateGeneralEvolveHandler=nil # Price rate general evolve handler.
    @stockRuleFactory = StockRuleFactory.new # Stock rule factory.
    @stockCostCalculator = StockCostCalculator.new # 创建评估对象
    @transactionListCache = {} # Transaction list cache.
    #@transactionListCache = TransactionListCache.new # Transaction list cache.
    @transactionListRequestIdQueue = [] # The reqeust id queue.
  end 
  
  #将价格调整成标准价格，向下调整
  def normalizePriceFloor(randomPrice)
      result=((randomPrice*100).floor)/100.0
  end #def normalizePriceFloor(randomPrice) #将价格调整成标准价格，向下调整
  
  #将价格调整成标准价格，向上调整
  def normalizePriceCeil(sellprice) 
      result=((sellprice*100).ceil)/100.0
  end #normalizePriceCeil(sellprice) #将价格调整成标准价格，向上调整
  
    #计算，比率值
    def calculateHighLowRate(buyInDateIndex, dateDataList) 
      priceMap=dateDataList[buyInDateIndex]['priceMap'] # 获取价格映射
      
      priceMin=priceMap['low'] #获取最低价
      priceHigh=priceMap['high'] #获取最高价
      
      lastDayPriceMap=dateDataList[buyInDateIndex+1]['priceMap'] #获取上一个日子的价格映射
      
      priceLastDateClose=lastDayPriceMap['close'] #获取上一个交易日的收盘价
      
      highRate=priceHigh/priceLastDateClose
      lowRate=priceMin/priceLastDateClose
      
      return highRate, lowRate
    end #calculateHighLowRate(buyInDateIndex, dateDataList) #计算，比率值
    
    #获取随机买入价格。
    def getRandomBuyInPrice(buyInDateIndex, dateDataList)
      priceMap=dateDataList[buyInDateIndex]['priceMap'] # 获取价格映射
      
      priceMin=priceMap['low'] #获取最低价
      priceHigh=priceMap['high'] #获取最高价
      
      randomPrice=rand()*(priceHigh-priceMin)+priceMin #计算出一个随机价格
      
      randomPrice=normalizePriceFloor(randomPrice) #将价格调整成标准价格，向下调整
      
      print("random price: #{randomPrice}\n") 
      
      randomPrice
    end #getRandomBuyInPrice(buyInDateIndex, dateDataList) #获取随机买入价格。
    
    #计算出买入数量。
    def calculateBuyInAmount(buyInPrice, initialMoney) 
        availableAmount=initialMoney/buyInPrice #计算出总共可用的数量
        
        result=((availableAmount/100).floor)*100
    end #calculateBuyInAmount(buyInPrice, initialMoney) #计算出买入数量。
    
    #计算卖出价格
    def calculateSellPrice(buyInPrice, buyInAmount, targetProfit) 
      buytotal=calculatebuymoney(buyInPrice, buyInAmount)
      profit=targetProfit
      buyamount=buyInAmount
      
      sellpure=buytotal+profit
      sellfee=[sellpure*0.0003,5].max
      selltotal=sellpure/(1-0.001)+sellfee
      sellprice=selltotal/buyamount
      
      sellprice=normalizePriceCeil(sellprice) #将价格调整成标准价格，向上调整
    end #calculateSellPrice(buyInPrice, buyInAmount, targetProfit) #计算卖出价格
    
    #计算持有收益
    def calculateHoldProfit(buyInAmount, buyInPrice, targetSellPrice) 
      normalsell=targetSellPrice
      #buyamount=buyInAmount
      
      buytotal=0
      currentbuymoney=calculatebuymoney(buyInPrice, buyInAmount)
      
      buytotal=buytotal+currentbuymoney
      
      actualselltotal=normalsell*buyInAmount
      actualprofit=actualselltotal*(1-0.0003-0.001)-buytotal
    end #calculateHoldProfit(buyInAmount, buyInPrice, targetSellPrice) #计算持有收益
    
    #计算，持有天数，持有收益。依据是，买入日期下标，死期日期下标，价格列表，初始资金，目标盈利
    def calculateHoldResult(buyInDateIndex, deadlineDateIndex, dateDataList, initialMoney, targetProfit)
      holdDateAmount=0 #持有天数
      holdProfit=0 #持有收益
      sellPrice=0 #卖出价格
      
      buyInPrice=getRandomBuyInPrice(buyInDateIndex, dateDataList) #获取随机买入价格。
      
      buyInAmount=calculateBuyInAmount(buyInPrice, initialMoney) #计算出买入数量。
      
      targetSellPrice=calculateSellPrice(buyInPrice, buyInAmount, targetProfit) #计算卖出价格
      
      #一天天地向后找，是不是有哪天的价格在这个范围内，有的话就可以卖出。没有的话，根据死期的收盘价计算收益
      #日期index越大，日期越早
      
      searchPriceRange=(buyInDateIndex-1).downto(deadlineDateIndex) #价格搜索日期下标范围
      
      sellSuccessfully=false #是否成功按照目标价格卖出
      
      searchPriceRange.each do |currentSearchPriceDateIndex|
        priceMap=dateDataList[currentSearchPriceDateIndex]['priceMap'] #获取价格映射
        
        priceHigh=priceMap['high'] #最高价
        print("target sell price: #{targetSellPrice}, high price: #{priceHigh}\n")
        
        if (targetSellPrice<=priceHigh) #在最高价范围
          holdDateAmount=buyInDateIndex-currentSearchPriceDateIndex #计算出持有天数
          print("success hold date amount: #{holdDateAmount}\n")
          holdProfit=calculateHoldProfit(buyInAmount, buyInPrice, targetSellPrice) #计算持有收益
          sellPrice=targetSellPrice #卖出价格
          
          sellSuccessfully=true # 成功卖出
          
          break #跳出
        end #if (targetSellPrice<=priceHigh) #在最高价范围
      end # searchPriceRange.each do |currentSearchPriceDateIndex|
      
      if (sellSuccessfully) #成功卖出
      else #if (sellSuccessfully) # 成功卖出
        holdDateAmount=buyInDateIndex-deadlineDateIndex #计算出最终持有天数
        print("hold date amount: #{holdDateAmount}\n")
        
        deadlinePriceMap=dateDataList[deadlineDateIndex]['priceMap'] #获取死期那天的价格映射
        deadlineFinalPrice=deadlinePriceMap['close'] #死期的最终价格
        
        holdProfit=calculateHoldProfit(buyInAmount, buyInPrice, deadlineFinalPrice) #计算持有收益
        sellPrice=deadlineFinalPrice # 卖出价格
        
      end #if (sellSuccessfully) #成功卖出
      
      return holdDateAmount, holdProfit, buyInPrice, sellPrice # 返回结果
    end #calculateHoldResult(buyInDateIndex, deadlineDateIndex, dateDataList, initialMoney, targetProfit) #计算，持有天数，持有收益。依据是，买入日期下标，死期日期下标，价格列表，初始资金，目标盈利
    
    def generateRandomStockCode # 生成
      resultObject={} #结果对象
      
      stockJsonFile= './StockDataTools/'  +  'hundredStocksCode.csv' # 构造文件名
      
      
      arr_of_rows = CSV.read(stockJsonFile) #载入CSV
      
      randomIndex=rand(arr_of_rows.length-1)+1
      
      puts randomIndex
      
      result=arr_of_rows[randomIndex][1]
      
      puts result
      
      resultObject['stockCode']=result
      
      resultObject
    end #generateRandomStockCode() #生成
    
    
    
    #计算高频统计信息
    def calcuateHighFrequencyStatsStock(stockCode) 
      resultObject={} #结果对象
      
      #stockJsonFile= './StockDataTools/'  +  stockCode + '.index.json' #构造文件名
      
      dateDataList, _ =loadStockHistory(stockCode) # 载入股票历史数据。
      
      #if File.exists?(stockJsonFile) #数据文件存在
        #stockJsonContent=File.read(stockJsonFile) #读取全部内容
        
        #stockJsonObject=JSON.parse(stockJsonContent) #解析成JSON
        
        #puts("stockJsonObject.length: #{stockJsonObject.length}") #Debug.
        
        if (dateDataList.length>=8) # 数据长度足够
          #dateDataList=[] #日期价格列表。
          
          #stockJsonObject.each do |currentDate, currentDateData|
            #dateDataObject={} #日期数据对象
            
            #dateDataObject['date']=currentDate #记录日期。
            #dateDataObject['priceMap']=currentDateData #记录价格映射
            
            #dateDataList << dateDataObject #加入列表。
          #end #stockJsonObject.each do |currentDateMap|
          
          assessDateRange=0..6 #要评估的日期下标范围。
          
          highRateSum=0 #累加的持有天数
          lowRateSum=0 #累加的持有收益
          
          highRateMinimum=Float::INFINITY #高价比率的最低值
          lowRateMaximum=-Float::INFINITY #低价比率的最高值
          
          begin #开始计算，可能会有价格过贵，买不起的情况
            assessDateRange.each do |currentDateIndex|
              buyInDateIndex=currentDateIndex #买入日期下标。
              deadlineDateIndex=0 #死期日期下标，最后一个日子
              
              highRate, lowRate = calculateHighLowRate(buyInDateIndex, dateDataList) # 计算，比率值
              
              highRateMinimum=[highRateMinimum, highRate].min #计算高价的低值
              lowRateMaximum=[lowRateMaximum, lowRate].max #计算低价的高值
              
              print("high rate: #{highRate}, low rate: #{lowRate}\n\n")
              
              highRateSum=highRateSum+highRate #累加最高价的比率
              lowRateSum=lowRateSum+lowRate #累加最低价的比率
            end #assessDateRange.each do |currentDateIndex|
            
            averageHighRate=highRateSum/assessDateRange.size
            averageLowRate=lowRateSum/assessDateRange.size
            averageProfitRate=averageHighRate-averageLowRate
            
            #print("high rate average: #{averageHighRate}, low rate average: #{averageLowRate}, profit average: #{averageProfitRate}\n\n")
            
            resultObject['averageHighRate']=averageHighRate
            resultObject['averageLowRate']=averageLowRate
            resultObject['averageProfitRate']=averageProfitRate
            resultObject['highRateMinimum']=highRateMinimum
            resultObject['lowRateMaximum']=lowRateMaximum
          rescue FloatDomainError => e #无限大
            puts("rescue, #{e}") #Debug
            
            resultObject['errorCode']=10285 #错误码。股票价格过高，买不起
          end #begin #开始计算，可能会有价格过贵，买不起的情况
        else #数据长度不够
          resultObject['errorCode']=10362 #错误码。股票数据不足
        end # if (stockJsonObject.length>=8) #数据长度足够
      
      resultObject
    end #calcuateHighFrequencyStatsStock(stockCode) #评估
    
     # Get transaction list.
    def get( requestId)
      transactionList = @transactionListCache[requestId]  # Remember the transaction list in cache.
      #transactionList = @transactionListCache.get(requestId)  # Remember the transaction list in cache.
      #@transactionListCache[requestId]= transactionList # Remember the transaction list in cache.
      #resultObject['transactionList'] = transactionList # 记录，交易列表 陈欣
      
      #puts("#{self.class.name}, #{__LINE__}, transaction list: #{transactionList}, request id: #{requestId}") # Debug.
      
      transactionList

      #resultObject
    end # getTransactionList( requestId) # Get transaction list.
    
    #评估。按照 rule list 买卖的收益
    def assessStockPriceGeneralEvolve(stockCodeOrAlias, moneyInput, dayAmount, ruleList, requestId)
      resultObject = assessStockPriceGeneralEvolveRuleList(stockCodeOrAlias, moneyInput, dayAmount, ruleList, requestId) # use rule list general evolve code.
      
      resultObject
    end #assessStockPriceRate(stockCode, moneyInput, highRate, lowRate) #评估。按照比例买卖的收益
    
    #评估。按照 rule list 买卖的收益. Use rule list code of price evolve.
    def put(requestId, transactionList)
        @transactionListCache[requestId]= transactionList # Remember the transaction list in cache.
            #@transactionListCache.put(requestId,  transactionList )# Remember the transaction list in cache.

        @transactionListRequestIdQueue << requestId # append to queue.
        
        dropOldEntries # drop old entries.
    end #assessStockPriceRate(stockCode, moneyInput, highRate, lowRate) #评估。按照比例买卖的收益
    
    #计算出理想的卖出价. By using rule list.
    def dropOldEntries
      if (@transactionListRequestIdQueue.size > RequestIdQueueSize) # too big.
        oldEntry = @transactionListRequestIdQueue.shift # get the first entry
        
        #chen xin
        @transactionListCache.delete(oldEntry) # remove entry.
      end # if (transactionListRequestIdQueue.size > RequestIdQueueSize) # too big.
    end # def findSellOutPriceByRules( dateDataList, ruleList, currentCandidateSellDateIndx ) #计算出理想的卖出价. By using rule list.

    # 计算出理想的买入价. By using rule list.
    def findBuyInPriceByRules( dateDataList , ruleList, currentCandidateBuyInDateINdex)
      candidateBuyInPriceList = [] # candidate buy in price list.

      ruleList.each do |currentRule| # check rules one by one
        currentBuyInPrice = currentRule.getBuyInPrice( dateDataList, currentCandidateBuyInDateINdex ) # Get the buy in price suggested by this rule.
        # puts "#{__LINE__}, current buy in price: #{currentBuyInPrice}, rule: #{currentRule}" # Debug.
        
        unless currentBuyInPrice.nil? # Gave valid buy in price
          candidateBuyInPriceList << currentBuyInPrice
        end # if currentBuyInPrice.nil? # Cannot give buy in price from this rule
      end # ruleList.each do |currentRule| # check rules one by one

      result = candidateBuyInPriceList.max # get the max price of buy in.
      # puts "#{__LINE__}, result: #{result}" # Debug.
      
      result
    end # def findBuyInPriceByRules( dateDataList , ruleList, currentCandidateBuyInDateINdex) # 计算出理想的买入价. By using rule list.
    
    #寻找满足要求的买卖对，并且加入到事务列表中. Use rule list code
    def findRuleListBuySellPairAddTransaction(initialMoney, dateDataList, allowedBuyInDateIndex, ruleList, sellRuleList) 
      # puts "#{__LINE__}, " # Debug.
      buyInPrice=0 #买入价
      buyInDate='' #买入日期
      allowedSellDateIndex=0 #允许的卖出日期下标
      buyInAmount=0 #买入价格
      buyInTransaction={} # 买入交易 对象
      buyInDateDuration=0 #买入的日期差
      lastTransactionDate = nil # The date of the last meaningful transaction.
      
      currentCandidateBuyInDateINdex=allowedBuyInDateIndex # candidate buy in data index.
      
      while currentCandidateBuyInDateINdex>=0 do
        priceMap=dateDataList[currentCandidateBuyInDateINdex]['priceMap'] #获取价格映射
        priceMin=priceMap['low'] #获取最低价
        priceMax = priceMap['high'] # Get the highest price.
        priceMapLastDate=dateDataList[currentCandidateBuyInDateINdex+1]['priceMap'] #获取上一天的价格映射
        priceHigh=priceMapLastDate['close'] #获取上一天收盘价


        # idealBuyInPrice=normalizePriceFloor(priceHigh*lowRate) #计算出理想的买入价

        # puts "#{__LINE__}, going to call findBuyInPriceByRules" # Debug.
        idealBuyInPrice = findBuyInPriceByRules( dateDataList , ruleList, currentCandidateBuyInDateINdex) # 计算出理想的买入价. By using rule list.

        
        if  (!idealBuyInPrice.nil?) && (idealBuyInPrice>=priceMin) && (idealBuyInPrice <= priceMax) #在价格范围内
          buyInPrice=idealBuyInPrice #买入价，记录
          buyInDate=dateDataList[currentCandidateBuyInDateINdex]['date'] # 获取日期，记录买入日期。陈欣
          allowedSellDateIndex=currentCandidateBuyInDateINdex-1 # 记录，允许卖出的日期下标
          buyInDateDuration=@lastOperationDateINdex-currentCandidateBuyInDateINdex #记录日期差
          @lastOperationDateINdex=currentCandidateBuyInDateINdex #记录，上次操作的日期下标
          
          lastTransactionDate = buyInDate # Remember last meaningful transaction date.
        
          break #不用再找了
        end #if (idealBuyInPrice>=priceMin) #在价格范围内

        currentCandidateBuyInDateINdex -=1
      end #dateIndexRange.each do |currentCandidateBuyInDateINdex| #一个个地检查是不是可以买
      
      sellPrice=0 #计算出的卖出价格
      sellDateIndex=0 #寻找到的卖出日期的下标
      sellDate='' #卖出日期字符串。陈欣
      sellTransaction={} # 卖出交易对象
      
      if (buyInPrice>0) #有找到合适的买入价。继续后面的计算
        allowedSellDateIndex=[allowedSellDateIndex, 0].max #不能小于0
        buyInAmount=calculateBuyInAmount(buyInPrice, initialMoney) #计算买入数量
        
        buyInTransaction['type']= ValueCode::Buy # 类型，买入
        
        # buyInTransaction['price']=buyInPrice #买入价格
        buyInTransaction[FieldCode::Price] = buyInPrice #买入价格

        buyInTransaction['amount']=buyInAmount #买入数量
        buyInTransaction['date']=buyInDate # 买入日期
        buyInTransaction['dateDuration']=buyInDateDuration #记录日期差
        
        currentCandidateSellDateIndx = allowedSellDateIndex
        
        while currentCandidateSellDateIndx >=0 do
          priceMap=dateDataList[currentCandidateSellDateIndx]['priceMap'] #获取价格映射
          priceMin=priceMap['low'] #获取最低价
          priceMax=priceMap['high'] #获取最高价
            
          priceMapLastDate=dateDataList[currentCandidateSellDateIndx+1]['priceMap'] #获取上一天的价格映射
            
          priceHigh=priceMapLastDate['close'] #获取上一天收盘价
            
          if (currentCandidateSellDateIndx==@lastOperationDateINdex) # 已经是最后一天了
            #price
            idealBuyInPrice=priceMap['close'] #按照收盘价计算卖出
          else #不是最后一天
            # idealBuyInPrice=normalizePriceCeil(priceHigh*highRate) #计算出理想的卖出价
            idealBuyInPrice=findSellOutPriceByRules( dateDataList, sellRuleList, currentCandidateSellDateIndx ) # 计算出理想的卖出价. By using rule list.
          end #if (currentCandidateSellDateIndx<=@lastOperationDateINdex) #已经是最后一天了
            
          if (!idealBuyInPrice.nil?) && (idealBuyInPrice<=priceMax)  && (idealBuyInPrice >= priceMin) #在价格范围内
            sellPrice=idealBuyInPrice #卖出价，记录
            sellDate=dateDataList[currentCandidateSellDateIndx]['date'] #卖出日期，记录。陈欣
            
            lastTransactionDate = sellDate # Remember last meaningful transaction date.
            
            sellDateIndex=currentCandidateSellDateIndx #记录，卖出的日期下标
            buyInDateDuration=@lastOperationDateINdex - sellDateIndex #记录日期差
            @lastOperationDateINdex=currentCandidateSellDateIndx #记录，上次操作的日期下标
              
            break #不用再找了
          end #if (idealBuyInPrice>=priceMin) #在价格范围内
          
          currentCandidateSellDateIndx -= 1
        end # sellDateIndexRange.each do |currentCandidateSellDateIndx| #一个个地计算是否可以卖
          
        if (sellPrice>0) # 循环过程中找到了合适的卖出价和卖出日期
        else # 循环过程中未找到合适的卖出价和卖出日期. Compendating the last sell transaction.
          priceMapLastDate=dateDataList[0]['priceMap'] # 获取最后一天的价格映射
            
          priceHigh=priceMapLastDate['close'] #获取上一天收盘价
            
          sellPrice=priceHigh #以最后收盘价作为卖出价
          sellDate=dateDataList[0]['date'] #卖出日期，记录。陈欣
          sellDateIndex=0 #最后 一天作为卖出的天
          buyInDateDuration=@lastOperationDateINdex - sellDateIndex #记录日期差
          @lastOperationDateINdex=0 #记录，上次操作的日期下标
        end #if (sellPrice>0) #循环过程中找到了合适的卖出价和卖出日期
          
        sellTransaction['type']= ValueCode::Sell # 卖出，类型

        # sellTransaction['price']=sellPrice #价格
        sellTransaction[FieldCode::Price] = sellPrice # Sell price

        sellTransaction['date']=sellDate # 卖出日期
        sellTransaction['amount']=buyInAmount #数量
        sellTransaction['dateDuration']=buyInDateDuration #计算日期差
          
        allowedBuyInDateIndex=sellDateIndex-1 #更新，下次允许的买入日期下标
      else # 未找到合适的买入价
        allowedBuyInDateIndex=-1 #不可再买入了
      end #if (buyInPrice>0) #有找到合适的买入价
        
      return allowedBuyInDateIndex, buyInTransaction, sellTransaction
    end #findPriceRateBuySellPairAddTransaction(initialMoney, highRate, lowRate, dateDataList, allowedBuyInDateIndex) #寻找满足要求的买卖对，并且加入到事务列表中
    
    #寻找满足要求的买卖对，并且加入到事务列表中
    def findPriceRateBuySellPairAddTransaction(initialMoney, highRate, lowRate, dateDataList, allowedBuyInDateIndex) 
      #dateIndexRange=allowedBuyInDateIndex.downto(0) # 可以用来考虑买入的日期下标范围
      
      buyInPrice=0 #买入价
      buyInDate='' #买入日期
      allowedSellDateIndex=0 #允许的卖出日期下标
      buyInAmount=0 #买入价格
      buyInTransaction={} # 买入交易 对象
      buyInDateDuration=0 #买入的日期差
      #         @lastOperationDateINdex=allowedBuyInDateIndex #上次操作的日期下标
      
      currentCandidateBuyInDateINdex=allowedBuyInDateIndex # candidate buy in data index.
      
      while currentCandidateBuyInDateINdex>=0 do
      
      #dateIndexRange.each do |currentCandidateBuyInDateINdex| #一个个地检查是不是可以买
        priceMap=dateDataList[currentCandidateBuyInDateINdex]['priceMap'] #获取价格映射
        priceMin=priceMap['low'] #获取最低价
        priceMapLastDate=dateDataList[currentCandidateBuyInDateINdex+1]['priceMap'] #获取上一天的价格映射
        priceHigh=priceMapLastDate['close'] #获取上一天收盘价
        idealBuyInPrice=normalizePriceFloor(priceHigh*lowRate) #计算出理想的买入价
        
        if (idealBuyInPrice>=priceMin) #在价格范围内
          buyInPrice=idealBuyInPrice #买入价，记录
          buyInDate=dateDataList[currentCandidateBuyInDateINdex]['date'] # 获取日期，记录买入日期。陈欣
          allowedSellDateIndex=currentCandidateBuyInDateINdex-1 # 记录，允许卖出的日期下标
          buyInDateDuration=@lastOperationDateINdex-currentCandidateBuyInDateINdex #记录日期差
          @lastOperationDateINdex=currentCandidateBuyInDateINdex #记录，上次操作的日期下标
          
          break #不用再找了
        end #if (idealBuyInPrice>=priceMin) #在价格范围内

        currentCandidateBuyInDateINdex -=1
      end #dateIndexRange.each do |currentCandidateBuyInDateINdex| #一个个地检查是不是可以买
      
      sellPrice=0 #计算出的卖出价格
      sellDateIndex=0 #寻找到的卖出日期的下标
      sellDate='' #卖出日期字符串。陈欣
      sellTransaction={} # 卖出交易对象
      
      if (buyInPrice>0) #有找到合适的买入价。继续后面的计算
        allowedSellDateIndex=[allowedSellDateIndex, 0].max #不能小于0
        buyInAmount=calculateBuyInAmount(buyInPrice, initialMoney) #计算买入数量
        
        #buyInTransaction['type']='buy' # 类型，买入
        buyInTransaction['type']= ValueCode::Buy # 类型，买入
        
        
        buyInTransaction['price']=buyInPrice #买入价格
        buyInTransaction['amount']=buyInAmount #买入数量
        buyInTransaction['date']=buyInDate # 买入日期
        buyInTransaction['dateDuration']=buyInDateDuration #记录日期差
        
        #sellDateIndexRange=allowedSellDateIndex.downto(0) #允许用于寻找 卖出价格的日期下标范围
        
        currentCandidateSellDateIndx = allowedSellDateIndex
        
        while currentCandidateSellDateIndx >=0 do
        
        #sellDateIndexRange.each do |currentCandidateSellDateIndx| #一个个地计算是否可以卖
          priceMap=dateDataList[currentCandidateSellDateIndx]['priceMap'] #获取价格映射
          
          priceMax=priceMap['high'] #获取最高价
            
          priceMapLastDate=dateDataList[currentCandidateSellDateIndx+1]['priceMap'] #获取上一天的价格映射
            
          priceHigh=priceMapLastDate['close'] #获取上一天收盘价
            
          if (currentCandidateSellDateIndx==@lastOperationDateINdex) # 已经是最后一天了
            #price
            idealBuyInPrice=priceMap['close'] #按照收盘价计算卖出
          else #不是最后一天
            idealBuyInPrice=normalizePriceCeil(priceHigh*highRate) #计算出理想的卖出价
          end #if (currentCandidateSellDateIndx<=@lastOperationDateINdex) #已经是最后一天了
            
          if (idealBuyInPrice<=priceMax) #在价格范围内
            sellPrice=idealBuyInPrice #卖出价，记录
            sellDate=dateDataList[currentCandidateSellDateIndx]['date'] #卖出日期，记录。陈欣
            sellDateIndex=currentCandidateSellDateIndx #记录，卖出的日期下标
            buyInDateDuration=@lastOperationDateINdex - sellDateIndex #记录日期差
            @lastOperationDateINdex=currentCandidateSellDateIndx #记录，上次操作的日期下标
              
            break #不用再找了
          end #if (idealBuyInPrice>=priceMin) #在价格范围内
          
          currentCandidateSellDateIndx -= 1
        end # sellDateIndexRange.each do |currentCandidateSellDateIndx| #一个个地计算是否可以卖
          
        if (sellPrice>0) # 循环过程中找到了合适的卖出价和卖出日期
        else #循环过程中未找到合适的卖出价和卖出日期
          priceMapLastDate=dateDataList[0]['priceMap'] # 获取最后一天的价格映射
            
          priceHigh=priceMapLastDate['close'] #获取上一天收盘价
            
          sellPrice=priceHigh #以最后收盘价作为卖出价
          sellDate=dateDataList[0]['date'] #卖出日期，记录。陈欣
          sellDateIndex=0 #最后 一天作为卖出的天
          buyInDateDuration=@lastOperationDateINdex - sellDateIndex #记录日期差
          @lastOperationDateINdex=0 #记录，上次操作的日期下标
        end #if (sellPrice>0) #循环过程中找到了合适的卖出价和卖出日期
          
        #sellTransaction['type']='sell' #卖出，类型
        sellTransaction['type']= ValueCode::Sell # 卖出，类型
        sellTransaction['price']=sellPrice #价格
        sellTransaction['date']=sellDate # 卖出日期
        sellTransaction['amount']=buyInAmount #数量
        sellTransaction['dateDuration']=buyInDateDuration #计算日期差
          
        allowedBuyInDateIndex=sellDateIndex-1 #更新，下次允许的买入日期下标
      else # 未找到合适的买入价
        allowedBuyInDateIndex=-1 #不可再买入了
      end #if (buyInPrice>0) #有找到合适的买入价
        
      return allowedBuyInDateIndex, buyInTransaction, sellTransaction
    end #findPriceRateBuySellPairAddTransaction(initialMoney, highRate, lowRate, dateDataList, allowedBuyInDateIndex) #寻找满足要求的买卖对，并且加入到事务列表中

    # 载入股票历史数据
    def loadStockHistory(stockCodeOrAlias)
      @stockHistoryReporter.loadStockHistory(stockCodeOrAlias) # Use the history reporter to load stock history
    end # def loadStockHistory(stockCode)
    
    #评估股票
    def assessStock(stockCode, moneyInput, expectedProfit)
      resultObject={} #结果对象
      
      dateDataList, _ = loadStockHistory(stockCode) # 载入股票历史数据。
      
      if (dateDataList.length>=8) #数据长度足够
        #dateDataList=[] #日期价格列表。
        
        #stockJsonObject.each do |currentDate, currentDateData|
        #dateDataObject={} #日期数据对象
        
        #dateDataObject['date']=currentDate #记录日期。
        #dateDataObject['priceMap']=currentDateData #记录价格映射
        
        #dateDataList << dateDataObject #加入列表。
        #end #stockJsonObject.each do |currentDateMap|
        
        assessDateRange=1..7 #要评估的日期下标范围。
        
        initialMoney=moneyInput #初始资金数
        targetProfit=expectedProfit #目标盈利数
        
        holdDateAmountSum=0 #累加的持有天数
        holdProfitSum=0 #累加的持有收益
        buyInPriceSum=0 # 累加的买入价格
        sellPriceSum=0 #累加卖出价格
        
        
        begin #开始计算，可能会有价格过贵，买不起的情况
          assessDateRange.each do |currentDateIndex|
            buyInDateIndex=currentDateIndex #买入日期下标。
            deadlineDateIndex=0 #死期日期下标，最后一个日子
            
            holdDateAmount, holdProfit, buyInPrice, sellPrice= calculateHoldResult(buyInDateIndex, deadlineDateIndex, dateDataList, initialMoney, targetProfit) #计算，持有天数，持有收益。依据是，买入日期下标，死期日期下标，价格列表，初始资金，目标盈利
            
            print("hold date amount: #{holdDateAmount}, hold profit: #{holdProfit}, buy in price: #{buyInPrice}\n\n")
            
            holdDateAmountSum=holdDateAmountSum+holdDateAmount #累加持有天数
            holdProfitSum=holdProfitSum+holdProfit #累加持有收益
            buyInPriceSum=buyInPriceSum+buyInPrice # 累加买入价格
            sellPriceSum=sellPriceSum+sellPrice #累加卖出价格
          end #assessDateRange.each do |currentDateIndex|
          
          averageHoldDateAmount=holdDateAmountSum/assessDateRange.size
          averageHoldProfit=holdProfitSum/assessDateRange.size
          averageBuyInPrice=buyInPriceSum/assessDateRange.size
          averageSellPrice=sellPriceSum/assessDateRange.size
          
          averageBuyInPrice=normalizePriceFloor(averageBuyInPrice) #调整价格
          averageSellPrice=normalizePriceFloor(averageSellPrice) #调整价格
          
          print("hold date average: #{averageHoldDateAmount}, hold profit average: #{averageHoldProfit}, buy in price average: #{averageBuyInPrice}\n\n")
          
          averageBuyAmount=(((initialMoney/averageBuyInPrice)/100.0).ceil)*100 #计算平均买入数量
          
          #resultObject['averageHoldDateAmount']=averageHoldDateAmount
          resultObject[FieldCode::AverageHoldDateAmount] = averageHoldDateAmount


          resultObject['averageHoldProfit']=averageHoldProfit
          resultObject['averageBuyInPrice']=averageBuyInPrice
          resultObject['averageSellPrice']=averageSellPrice
          resultObject['averageBuyAmount']=averageBuyAmount
        rescue FloatDomainError => e #无限大
            puts("rescue, #{e}") #Debug
            
            resultObject['errorCode']=10285 #错误码。股票价格过高，买不起
          end # begin #开始计算，可能会有价格过贵，买不起的情况
        else #数据长度不够
          resultObject['errorCode']=10362 #错误码。股票数据不足
          
        end #if (stockJsonObject.length>=8) #数据长度足够
        
        
      resultObject
    end #def assessStock(stockCode)
end #class StockAssessor
