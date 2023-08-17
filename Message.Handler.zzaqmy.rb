#!/usr/bin/env ruby

#require 'eventchart.js'

class MessageHandler
  KeepAliveResponse={'function':'KeepAliveResponse'} # 保持连接的回复。
  
  def initialize
    @stockAssessor=StockAssessor.new # 创建评估对象
    @stockHistoryReporter=StockHistoryReporter.new # 创建 stock history manager
    @transactionList={} # 上次请求计算卖出价格时，提供的事务列表对象。陈欣
    #@eventChart=EventChart.new # Create a new event chart object.
    
    @stockAssessor.stockHistoryReporter=@stockHistoryReporter # 设置历史报告器
    @stockAssessor.eventChart=@eventChart # Set the vent chart object
  end  #def initialize
    
  def receive_data(command)
    #@eventChart.reportEvent('requestStart', {time: Time.now.to_f})
    messageObject=CBOR.decode(command) # 解码
    # puts "#{__LINE__}, #{self.class.name}, message object: #{messageObject}" # Debug.
    
    resultObject = processMessage(messageObject) #处理消息
    # puts "#{__LINE__}, #{self.class.name}, result object: #{resultObject}" # Debug.
    
    resultMessage=resultObject.to_cbor # 序列化

    resultMessage
  end
  
   # Handle the request of getting transaction list.
  def processGetTransactionList(messageObject)
    requestId=messageObject['requestId'] # 请求编号
    
    requestId||=messageObject[FieldCode::RequestId] # 请求编号
    
    resultObject = getTransactionList(requestId) # Get transaction list.

    resultObject[FieldCode::Function] = FunctionCode::GetTransactionListResponse # 标记功能

    resultObject['requestId']=requestId # 加入请求编号。
    
    resultObject
  end # processGetTransactionList(messageObject) # Handle the request of getting transaction list.

  def processAssessStockGenelralEvolve(messageObject)
    stockCodeOrAlias=messageObject['stockCode'] || messageObject['stockCodeAlias'] # 获取股票代号 or alias

    moneyInput = messageObject['initialMoney'] || messageObject[FieldCode::InitialMoney] # 获取初始本金
    
    dayAmount = messageObject['dayAmount'] # 天数。这个参数要详细规定下其意义。

    dayAmount ||= messageObject[FieldCode::DayAmount] # 天数。这个参数要详细规定下其意义。

    requestId=messageObject['requestId'] # 请求编号
    
    requestId||=messageObject[FieldCode::RequestId] # 请求编号
    
    ruleList=messageObject[FieldCode::RuleList] # get the rule list.
    
    unless requestId # 没有提供请求编号。
      puts "message object: #{messageObject}"
    end # unless requestId # 没有提供请求编号。
    
    # puts "request id: #{requestId}" # Debug.
    
    resultObject= assessStockPriceGeneralEvolve(stockCodeOrAlias, moneyInput, dayAmount, ruleList, requestId) # 评估股票。按照 rule list 买卖的收益

    resultObject[FieldCode::Function]=FunctionCode::AssessStockPriceGeneralEvolveResponse # 标记功能

    resultObject['requestId']=requestId # 加入请求编号。
    
    resultObject
  end # def processAssessStockGenelralEvolve(messageObject)
  
  # 处理价格比率收益评估请求。
  def processAssessStockPriceRate(messageObject) 
    stockCodeOrAlias=messageObject['stockCode'] || messageObject['stockCodeAlias'] # 获取股票代号 or alias

    moneyInput=messageObject['initialMoney'] #获取初始本金
    highRate=messageObject['highRate'] #高价比例
    
    #lowRate=messageObject['lowRate'] # 低价比例
    lowRate=messageObject[FieldCode::LowRate] # 低价比例
    
    #puts "low rate: #{lowRate}" # debug.
    
    wholeHistory=messageObject['wholeHistory'] #是否要评估整个历史

    dayAmount = messageObject['dayAmount'] # 天数。这个参数要详细规定下其意义。

    dayAmount ||= messageObject[FieldCode::DayAmount] # 天数。这个参数要详细规定下其意义。

    requestId=messageObject['requestId'] # 请求编号
    
    requestId||=messageObject[FieldCode::RequestId] # 请求编号
    
    unless requestId # 没有提供请求编号。
      puts "message object: #{messageObject}"
    end # unless requestId # 没有提供请求编号。
    
    resultObject=assessStockPriceRate(stockCodeOrAlias, moneyInput, highRate, lowRate, wholeHistory, dayAmount) # 评估股票。按照比例买卖的收益

    #resultObject['function']='AssessStockPriceRateResponse' #标记功能
    resultObject[FieldCode::Function]=FunctionCode::AssessStockPriceRateResponse # 标记功能
    #resultObject[FieldCode::Function]=FunctionCode::ExzReportHistoryResponse # 标记功能

    resultObject['requestId']=requestId # 加入请求编号。
    
    if (resultObject['errorCode'])
      #puts "#{__LINE__}, processAssessStockPriceRate, result object stock code alias: #{resultObject['stockCodeAlias']}, stock code or alias: #{stockCodeOrAlias}, error code: #{resultObject['errorCode']}" # Debug.
    end
    resultObject
  end
  
  # 处理请求，计算清仓价格。
  def processCalculateSellOutPrice(messageObject) 
    @transactionList=messageObject['transactionList'] #获取事务列表JSON
    #             moneyInput=messageObject['moneyInput'] #获取初始本金
    expectedProfit=messageObject['expectedProfit'] # 预期收益
    
    resultObject=calculateSellOutPrice(@transactionList, expectedProfit) #计算股票清仓价格
    resultObject['function']='CalculateSellOutPriceResponse' #标记功能
    resultObject
  end # processCalculateSellOutPrice(messageObject) # 处理请求，计算清仓价格。
  
  # 处理请求，评估股票。
  def processStockAssessRequest(messageObject) 
    stockCode=messageObject['stockCode'] # 获取股票代号
    moneyInput=messageObject['moneyInput'] # 获取初始本金
    expectedProfit=messageObject['expectedProfit'] # 预期收益
    
    resultObject=assessStock(stockCode, moneyInput, expectedProfit) # 评估股票
    resultObject['function']='StockAssessResponse' #标记功能
    resultObject
  end # processStockAssessRequest(messageObject) # 处理请求，评估股票。
  
  # 处理请求，计算补仓效果。
  def processCalculateFixEffect(messageObject) 
    holdPrice=messageObject['holdPrice'] # 获取事务列表JSON
    moneyInput=messageObject['moneyInput'] #获取初始本金
    holdAmount=messageObject['holdAmount'] #获取事务列表JSON
    fixLowPrice=messageObject['fixLowPrice'] # 获取初始本金
    fixHighPrice=messageObject['fixHighPrice'] #获取事务列表JSON
    expectedProfit=messageObject['expectedProfit'] #预期收益
    
    resultObject=calculateFixEffect(holdPrice, moneyInput, holdAmount, fixLowPrice, fixHighPrice, expectedProfit) #计算股票补仓效果
    resultObject['function']='CalculateFixEffectResponse' #标记功能
    resultObject
  end # processCalculateFixEffect(messageObject) # 处理请求，计算补仓效果。
  
  # 处理请求，获取收盘价格。
  def processGetClosePrice(messageObject) 
    stockCode=messageObject['stockCode'] # 获取股票代号
    
    resultObject = getClosePrice(stockCode) #获取股票的收盘价格
    
    resultObject['function']='GetClosePriceResponse' #标记功能
    resultObject
  end # processGetClosePrice(messageObject) # 处理请求，获取收盘价格。
  
  # 处理请求，获取最后发送过的交易事务列表。
  def processGetLastTransactionList 
    resultObject=getLastTransactionList() #获取历史事务列表
    
    resultObject['function']='GetLastTransactionListResponse' #标记功能
    resultObject
  end # processGetLastTransactionList # 处理请求，获取最后发送过的交易事务列表。
  
  #处理消息
  def processMessage(messageObject) 
    resultObject=nil # 结果对象
    function=messageObject['function'] # 获取功能
    # log("function: #{function}") # debug.
    
    case function #根据功能做不同的处理
    when 'StockAssessRequest' #评估股票
      resultObject=processStockAssessRequest(messageObject) # 处理请求，评估股票。
    when 'GetClosePrice' #获取收盘价格
      resultObject = processGetClosePrice(messageObject) # 处理请求，获取收盘价格。
    when 'GetLastTransactionList' #获取最后发送过的交易事务列表
      resultObject=processGetLastTransactionList # 处理请求，获取最后发送过的交易事务列表。
    #when 'AssessStockPriceRate' # 评估股票。按照比例买卖的收益情况
    when FunctionCode::AssessStockPriceRate # 评估股票。按照比例买卖的收益情况
      resultObject=processAssessStockPriceRate(messageObject) # 处理价格比率收益评估请求。
    when FunctionCode::AssessStockPriceGeneralEvolve # 评估股票。按照 rule list 买卖的收益情况
      resultObject = processAssessStockGenelralEvolve(messageObject) # 处理价格 rule list general evolve 收益评估请求。
    when FunctionCode::GetTransactionList # Get transaction list for request id
      resultObject = processGetTransactionList(messageObject) # Handle the request of getting transaction list.
    when FunctionCode::CalcuateHighFrequencyStats # 计算股票高频统计信息
      stockCode=messageObject['stockCode'] # 获取股票代号
      puts "stock code: #{stockCode}"  # Debug.
      
      resultObject=calcuateHighFrequencyStatsStock(stockCode) #计算股票高频统计信息
      resultObject['function']='CalcuateHighFrequencyStatsResponse' #标记功能
      resultObject
    when 'CalculateSellOutPrice' #计算清仓价格
      resultObject=processCalculateSellOutPrice(messageObject) # 处理请求，计算清仓价格。
    when 'CalculateFixEffect' #计算补仓效果
      resultObject=processCalculateFixEffect(messageObject) # 处理请求，计算补仓效果。
    when 'GenerateRandomStockCode' #生成随机股票代码
      resultObject=processGenerateRandomStockCode(messageObject) # 处理请求，生成随机股票代码。
    when 'UpdateStockHistory' # 更新股票历史数据
      resultObject=processUpdateStockHistory(messageObject) # 处理请求，更新股票历史数据。
    when 'ExzReportHistory' #报告股票历史数据. Exz 压缩。 陈欣
      resultObject=processExzReportHistory(messageObject) # 处理请求，以压缩包报告股票历史数据。
    when 'KeepAlive' # 保持连接活跃
      resultObject=KeepAliveResponse # 保持连接活跃的回复。
    when 'QueryExzReportHistoryStatus' #查询报告股票历史数据的状态. Exz 压缩。 陈欣
      resultObject=processQueryExzReportHistoryStatus # 处理请求，查询EXZ压缩报告历史数据的结果。
    when 'Khans' #加密数据。 陈欣
      resultObject=processKhans(messageObject) # 处理加密数据。
    else #其它功能
      log("Unknown function: #{function}")
      resultObject={} # 结果对象
    end
    
    #resultObject['originalFunction']=function # 加入原始请求中的功能名字。
    resultObject[FieldCode::OriginalFunction]=function # 加入原始请求中的功能名字。
    #resultObject[FieldCode::Function]=FunctionCode::ExzReportHistoryResponse # 标记功能
    
    resultObject #回复结果对象
  end # processMessage(messageObject) #处理消息
  
  # 处理加密数据。
  def processKhans(messageObject) 
    encryptedData=messageObject['game'] #获取加密后的内容。
    encryptionManager=EncryptionManager.new # 创建加密管理器。
    
    plainData=encryptionManager.decrypt(encryptedData); #解密数据，得到明文内容。
    
    plainmessageObject=CBOR.decode(plainData) # 解码
    
    resultObject=processMessage(plainmessageObject) #处理消息
    
    resultObject
  end # processKhans(messageObject) # 处理加密数据。
  
  # 处理请求，查询EXZ压缩报告历史数据的结果。
  def processQueryExzReportHistoryStatus 
    resultObject=queryExzReportStockHistoryStatus() #查询，报告股票历史的进程状态. Exz 压缩
    resultObject['function']='ExzReportHistoryResponse' # 标记功能
    resultObject
  end # processQueryExzReportHistoryStatus # 处理请求，查询EXZ压缩报告历史数据的结果。
  
  # 处理请求，以压缩包报告股票历史数据。
  def processExzReportHistory(messageObject) 
    stockHistoryList=messageObject['stockHistoryList'] #获取事务列表JSON
    
    resultObject=exzReportStockHistory(stockHistoryList) # 报告股票历史. Exz 压缩
    
    #resultObject['function']='ExzReportHistoryResponse' # 标记功能
    resultObject[FieldCode::Function]=FunctionCode::ExzReportHistoryResponse # 标记功能
    
    resultObject
  end # processExzReportHistory(messageObject) # 处理请求，以压缩包报告股票历史数据。
  
  # 处理请求，生成随机股票代码。
  def processGenerateRandomStockCode(messageObject) 
    resultObject=generateRandomStockCode() # 生成股票代码
    resultObject['function']='RandomStockCodeResponse' #标记功能
    resultObject
  end # processGenerateRandomStockCode(messageObject) # 处理请求，生成随机股票代码。
  
  # 处理请求，更新股票历史数据。
  def processUpdateStockHistory(messageObject) 
    stockCode=messageObject['stockCode'] #获取股票代号
    
    updateStockHistory(stockCode) # 更新股票的价格数据
    
    resultObject=getClosePrice(stockCode) #获取股票的收盘价格
    
    #resultObject['function']='GetClosePriceResponse' # 标记功能
    resultObject[FieldCode::Function]= FunctionCode::GetClosePriceResponse # 标记功能
    
    resultObject
  end # processUpdateStockHistory(messageObject) # 处理请求，更新股票历史数据。
  
  def queryExzReportStockHistoryStatus #查询，报告股票历史的进程状态. Exz 压缩
    result=@stockHistoryReporter.resultObject #回复，报告 Exz 压缩的历史数据，状态信息
  end #queryExzReportStockHistoryStatus() #查询，报告股票历史的进程状态. Exz 压缩
  
  #报告股票历史. Exz 压缩
  def exzReportStockHistory(transactionList)
    result=@stockHistoryReporter.exzReportStockHistory(transactionList) #报告 Exz 压缩的历史数据
  end #exzReportStockHistory(transactionList) #报告股票历史. Exz 压缩
  
  # 更新股票历史数据
  def updateStockHistory(stockCode)
    puts "stock code: #{stockCode}" # debug.
    result=@stockHistoryReporter.updateStockHistory(stockCode) # 更新
  end # def updateStockHistory(stockCode)
  
  # 生成随机股票代码
  def generateRandomStockCode() 
    stockAssessor=StockAssessor.new # 创建评估对象
    result=stockAssessor.generateRandomStockCode # 生成
  end #generateRandomStockCode() #生成股票代码
  
  #计算股票补仓效果
  def calculateFixEffect(holdPrice, moneyInput, holdAmount, fixLowPrice, fixHighPrice, expectedProfit) 
    stockAssessor=StockCostCalculator.new #创建评估对象
    result=stockAssessor.calculateFixEffect(holdPrice, moneyInput, holdAmount, fixLowPrice, fixHighPrice, expectedProfit) #计算补仓效果
  end #calculateFixEffect(holdPrice, moneyInput, holdAmount, fixLowPrice, fixHighPrice, expectedProfit) #计算股票补仓效果
  
  #计算股票清仓价格
  def calculateSellOutPrice(transactionList, expectedProfit) 
    stockAssessor=StockCostCalculator.new #创建评估对象
    result=stockAssessor.calculateSellOutPrice(transactionList, expectedProfit) #计算清仓价格
  end #calculateSellOutPrice(transactionList, expectedProfit) #计算股票清仓价格
  
  #计算股票高频统计信息
  def calcuateHighFrequencyStatsStock(stockCode) 
    result=@stockAssessor.calcuateHighFrequencyStatsStock(stockCode) # 评估
  end #calcuateHighFrequencyStatsStock(stockCode) #计算股票高频统计信息
  
  # 获取历史事务列表
  def getLastTransactionList() 
    resultObject={} # 结果对象
    
    resultObject['transactionList']=@transactionList #加入事务列表字段
    
    resultObject
  end #def getLastTransactionList()
  
  #获取股票的收盘价格
  def getClosePrice(stockCode) 
    puts("__LINE__, getClosePrice, stock code: #{stockCode}")

    result=@stockAssessor.getClosePrice(stockCode) #查询收盘价格
  end # getClosePrice(stockCode, moneyInput, expectedProfit) #获取股票的收盘价格
  
  # 评估股票
  def assessStock(stockCode, moneyInput, expectedProfit) 
    result=@stockAssessor.assessStock(stockCode, moneyInput, expectedProfit) #评估
  end #assessStock(stockCode) #评估股票
  
   # Get transaction list.
  def getTransactionList(requestId)
    result = @stockAssessor.getTransactionList(requestId) # Get transaction list.
    result
  end # getTransactionList(requestId) # Get transaction list.
  
  #评估股票。按照 rule list 买卖的收益
  def assessStockPriceGeneralEvolve(stockCodeOrAlias, moneyInput, dayAmount, ruleList, requestId)
    result = @stockAssessor.assessStockPriceGeneralEvolve(stockCodeOrAlias, moneyInput, dayAmount, ruleList, requestId) # 评估。按照 rule list 买卖的收益
    result
  end #assessStockPriceRate(stockCode, moneyInput, highRate, lowRate) #评估股票。按照比例买卖的收益
    
    
  #评估股票。按照比例买卖的收益
  def assessStockPriceRate(stockCodeOrAlias, moneyInput, highRate, lowRate, wholeHistory, dayAmount) 
    result=@stockAssessor.assessStockPriceRate(stockCodeOrAlias, moneyInput, highRate, lowRate, wholeHistory, dayAmount) # 评估。按照比例买卖的收益
    result
  end #assessStockPriceRate(stockCode, moneyInput, highRate, lowRate) #评估股票。按照比例买卖的收益
    
  def log(message)
    puts("#{DateTime.now.to_s} : #{message}")
  end
end # class MessageHandler
