# frozen_string_literal: true

#!/usr/bin/env ruby

require 'json' #json解析库。
require 'csv'
require 'extremeunzip.zzaqsu'
require 'tushare'
require 'byebug'

class StockCodeAliasNotExist < StandardError
  attr_accessor :resultObject #Exz解压状态对象
    
  # 载入股票历史数据
  def loadStockHistory(stockCodeOrAlias)
    dateDataList=@historyMap[stockCodeOrAlias] # Try to retrieve from history map.
    
    if (dateDataList.nil?) # not exists in history map
      if stockCodeOrAlias.is_a?(Integer) # it is an alias
        #Cgheb xin
        raise StockCodeAliasNotExist
      else # not an alias
        dateDataList||=loadStockHistoryFromStorage(stockCodeOrAlias)
      end # if stockCodeOrAlias.is_a?(Integer) # it is an alias
    else # exists in hisotry map
    end # if (dateDataList.nil?) # not exists in history map
      
    stockCodeAlias=@stockCodeAliasMap[stockCodeOrAlias] || stockCodeOrAlias
    return dateDataList, stockCodeAlias # return data list and stock code alias
  end # def loadStockHistory(stockCode)
    
  # 载入股票历史数据 from storage
  def loadStockHistoryFromStorage(stockCode)
    dateDataList=[] #日期价格列表。
    stockJsonFile= './StockDataTools/'  +  stockCode + '.index.json' #构造文件名
        
    if File.exists?(stockJsonFile) # 数据文件存在
      #byebug # debug.
      
      stockJsonContent=File.read(stockJsonFile) #读取全部内容
        
      stockJsonObject=JSON.parse(stockJsonContent) #解析成JSON

      #byebug
      
      stockJsonObject.each do |currentDateData|
        begin
          currentDate=currentDateData['date'] # 获取日期
          dateDataObject={} # 日期数据对象
            
          %w[open high close low].each do |priceName|
            currentDateData[priceName]=currentDateData[priceName].to_f # 转换成浮点数。
          end # %w[open high close low].each do |priceName|
            
          dateDataObject['date']=currentDate #记录日期。
          dateDataObject['priceMap']=currentDateData #记录价格映射
            
          dateDataList << dateDataObject #加入列表。
        rescue TypeError
        end
      end #stockJsonObject.each do |currentDateMap|
    end #if File.exists?(stockJsonFile) #数据文件存在
      
    @historyMap[stockCode]=dateDataList # Add to map
    @historyMap[@nextStockCodeAlias]=dateDataList # Add to map, by alias
    @stockCodeAliasMap[stockCode]=@nextStockCodeAlias # Remember stock code to alias map relation ship
    @nextStockCodeAlias=@nextStockCodeAlias+1 # allocate next available alias
      
    dateDataList # 回复数据列表
  end # def loadStockHistory(stockCode)
    
  def initialize 
    @actionId=0 #活动编号
    @p1=0 #解压子进程编号
    @resultObject={} #结果对象
    @historyMap={} # history map
    @nextStockCodeAlias = 0 # stock code alias
    @stockCodeAliasMap = {} # Remember stock code to alias map relation ship
  end 

  #将价格调整成标准价格，向下调整
  def normalizePriceFloor(randomPrice)
    result=((randomPrice*100).floor)/100.0
  end #def normalizePriceFloor(randomPrice) #将价格调整成标准价格，向下调整
    
    #将价格调整成标准价格，向上调整
    def normalizePriceCeil(sellprice) 
        result=((sellprice*100).ceil)/100.0
        
    end #normalizePriceCeil(sellprice) #将价格调整成标准价格，向上调整
    
    #获取随机买入价格。
    def getRandomBuyInPrice(buyInDateIndex, dateDataList)
        print("dateDateList: #{dateDataList}\n") #Debug
        priceMap=dateDataList[buyInDateIndex]['priceMap'] #获取价格映射
        
        priceMin=priceMap['low'] #获取最低价
        priceHigh=priceMap['high'] # 获取最高价
        
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
        
        sellprice=normalizePriceCeil(sellprice) # 将价格调整成标准价格，向上调整
    end #calculateSellPrice(buyInPrice, buyInAmount, targetProfit) #计算卖出价格
    
    #计算买入所花的钱
    def calculatebuymoney(buyInPrice, buyInAmount)
        buyprice=buyInPrice
        buyamount=buyInAmount
        buymoney=buyprice*buyamount
        
        
        workfee=buymoney*0.0003
        if (workfee<5)
            workfee=5
        end
        
        #print ("buy money #{buymoney} \n")
        buytotal=buymoney+workfee
    end #calculatebuymoney(buyInPrice, buyInAmount)
    
    #计算持有收益
    def calculateHoldProfit(buyInAmount, buyInPrice, targetSellPrice) 
        normalsell=targetSellPrice
        buyamount=buyInAmount
        
        buytotal=0
        currentbuymoney=calculatebuymoney(buyInPrice, buyInAmount)
        
        buytotal=buytotal+currentbuymoney
        
        
        actualselltotal=normalsell*buyamount
        actualprofit=actualselltotal*(1-0.0003-0.001)-buytotal
    end #calculateHoldProfit(buyInAmount, buyInPrice, targetSellPrice) #计算持有收益
    
    #计算，持有天数，持有收益。依据是，买入日期下标，死期日期下标，价格列表，初始资金，目标盈利
    def calculateHoldResult(buyInDateIndex, deadlineDateIndex, dateDataList, initialMoney, targetProfit)
        holdDateAmount=0 # 持有天数
        holdProfit=0 #持有收益
        sellPrice=0 # 卖出价格
        
        buyInPrice=getRandomBuyInPrice(buyInDateIndex, dateDataList) #获取随机买入价格。
        
        buyInAmount=calculateBuyInAmount(buyInPrice, initialMoney) #计算出买入数量。
        puts("buy in amoutn: #{buyInAmount}") #Debug
        
        targetSellPrice=calculateSellPrice(buyInPrice, buyInAmount, targetProfit) #计算卖出价格
        
        #一天天地向后找，是不是有哪天的价格在这个范围内，有的话就可以卖出。没有的话，根据死期的收盘价计算收益
        #日期index越大，日期越早
        
        searchPriceRange=(buyInDateIndex-1).downto(deadlineDateIndex) #价格搜索日期下标范围
        
        sellSuccessfully=false #是否成功按照目标价格卖出
        
        searchPriceRange.each do |currentSearchPriceDateIndex|
            priceMap=dateDataList[currentSearchPriceDateIndex]['priceMap'] #获取价格映射
            
            priceHigh=priceMap['high'] #最高价
            print("target sell price: #{targetSellPrice}, high price: #{priceHigh}\n")
            
            if (targetSellPrice<=priceHigh) # 在最高价范围
                holdDateAmount=buyInDateIndex-currentSearchPriceDateIndex #计算出持有天数
                print("success hold date amount: #{holdDateAmount}\n")
                holdProfit=calculateHoldProfit(buyInAmount, buyInPrice, targetSellPrice) #计算持有收益
                sellPrice=targetSellPrice #卖出价格
                
                sellSuccessfully=true #成功卖出
                
                break #跳出
            end #if (targetSellPrice<=priceHigh) #在最高价范围
        end # searchPriceRange.each do |currentSearchPriceDateIndex|
        
        if (sellSuccessfully) #成功卖出
        else #if (sellSuccessfully) #成功卖出
          holdDateAmount=buyInDateIndex-deadlineDateIndex #计算出最终持有天数
          print("hold date amount: #{holdDateAmount}\n")
            
          deadlinePriceMap=dateDataList[deadlineDateIndex]['priceMap'] #获取死期那天的价格映射
          deadlineFinalPrice=deadlinePriceMap['close'] #死期的最终价格
            
          holdProfit=calculateHoldProfit(buyInAmount, buyInPrice, deadlineFinalPrice) #计算持有收益
          sellPrice=deadlineFinalPrice #卖出价格
        end #if (sellSuccessfully) #成功卖出
        
        return holdDateAmount, holdProfit, buyInPrice, sellPrice # 返回结果
    end # calculateHoldResult(buyInDateIndex, deadlineDateIndex, dateDataList, initialMoney, targetProfit) #计算，持有天数，持有收益。依据是，买入日期下标，死期日期下标，价格列
    
    # 更新股票历史数据
    def updateStockHistory(stockCode)
      dataDirectory= './StockDataTools/'

      begin
        Dir.mkdir(dataDirectory) # Create directory
      rescue Errno::EEXIST
      end

      begin
        df=Tushare::Stock::Trading::get_hist_data(stockCode)
        
        jsonContent=df.to_json

        stockJsonFile=  dataDirectory +  stockCode+'.index.json' #构造文件名
        
        jsonFile=File.new(stockJsonFile, 'w')
        jsonFile.syswrite(jsonContent)
        jsonFile.close
        
      rescue RuntimeError
      rescue SocketError
      end
      
      loadStockHistoryFromStorage(stockCode) # Refresh cache
    end # updateStockHistory(stockCode) # 更新
    
    #报告 Exz 压缩的历史数据 陈欣
    def exzReportStockHistory(transactionList) 
      @resultObject={} #结果对象
        
      fileWriteError = false # 是否文件写入出错
        
      transactionList.each do |currentFileItem|
        fileName=currentFileItem['fileName'] #文件名
        fileContent=currentFileItem['fileContent'] #文件内容
        fileLength = currentFileItem['fileLength'] # 文件长度。陈欣
            
        curetnFileObject=File.open(fileName, 'w') # 打开文件
            
        actualWrittenLength =  curetnFileObject.syswrite(fileContent) #写入内容
            
        curetnFileObject.close #关闭
            
        if (actualWrittenLength < fileLength) # 实际写入长度不够。
          fileWriteError = true # 文件写入出错
                
          break # 不再继续处理
        else # 正常写入
          startExuz(fileName) #开始解压文件
        end # if (actualWrittenLength < fileLength) # 实际写入长度不够。
      end #transactionList.each do |currentFileItem|

      @actionId=rand()*110744 # 随机产生活动编号
        
      if fileWriteError # 文件写入出错
        @resultObject['success']=false # 尚未完成。后面还要解压缩
        @resultObject['status']='Failed' # 已失败
        @resultObject['errorMessage']='File write error. Maybe disk full.' # 文件写入出错。陈欣
        @resultObject['errorCode']= 155645 # 文件写入出错。陈欣。错误码
      else # 文件写入未出错
        @resultObject['success']=false #尚未完成。后面还要解压缩
        @resultObject['status']='OnGoing' #仍在进行中
      end # if fileWriteError # 文件写入出错

      #@resultObject['actionId']=@actionId # 设置活动编号
      @resultObject[FieldCode::ActionId]=@actionId # 设置活动编号

      @resultObject
    end # exzReportStockHistory(transactionList) #报告 Exz 压缩的历史数据
    
    #开始解压文件 陈欣
    def startExuz(fileName) 
      @p1 = fork do #复制出子进程
        rootPath=fileName # 记录要打包的目录树的根目录。
            
        exuzObject=ExtremeUnZip.new #解压对象
            
        exuzObject.exuz(rootPath) # 解压

        puts("finished #{Process.pid}") #Debug
      end #p1 = fork do #复制出子进程
        
      startCheckExuzProcess() #开始检查解压进程的状态
    end #startExuz(fileName) #开始解压文件
    
    #开始检查解压进程的状态
    def startCheckExuzProcess
      # 陈欣
        
      quitProcessId=Process.waitpid(@p1, Process::WNOHANG) #等待，但不阻塞
        
      if (quitProcessId.nil?) #尚未退出
        EventMachine.add_timer(5) { startCheckExuzProcess } # 再次定时检查
      else #已经退出
        puts "exit status: #{$?.exitstatus} #{__LINE__} #{$?.exitstatus}" # Debug
        if $?.exitstatus != 0 # 退出码大于0,有错误发生
          
          #@resultObject['success']=false # 未完成。
          @resultObject[FieldCode::Success]=false # 未完成。
          
          @resultObject['status']='Failed' # 已失败
          @resultObject['errorCode']=161418 # 解压出错
        else # 正常完成。
          
          #@resultObject['success']=true #已经完成。
          @resultObject[FieldCode::Success]=true #已经完成。
          
          @resultObject['status']='Finished' #已完成
          
          #陈欣，清空内存中的历史数据映射 @historyMap
          @historyMap.clear
        end # if $?.exitstatus # 退出码大于0,有错误发生
      end #if (quitProcessId.nil?) #尚未退出
    end #startCheckExuzProcess() #开始检查解压进程的状态

    def generateRandomStockCode() #生成
        resultObject={} # 结果对象

        stockJsonFile= './StockDataTools/'  +  'hundredStocksCode.csv' # 构造文件名
        
        
        arr_of_rows = CSV.read(stockJsonFile) #载入CSV

        randomIndex=rand(arr_of_rows.length-1)+1

        puts randomIndex

        result=arr_of_rows[randomIndex][1]
        
        puts result

        resultObject['stockCode']=result
        
        resultObject
    end #generateRandomStockCode() #生成
end #class StockAssessor

 
