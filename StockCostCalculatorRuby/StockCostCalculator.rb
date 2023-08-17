#!/usr/bin/env ruby

require 'json' # json解析库。
require 'oj' #optimized json

class StockCostCalculator
  #计算单次购买记录产生的成本：
  def calculatebuymoney(buyentry)

    #buyprice=buyentry['price'] # get buy price
    buyprice=buyentry[FieldCode::Price] || buyentry['price'] # get buy price

    buyamount=buyentry['amount']
    buymoney=buyprice*buyamount

    workfee = [buymoney*0.0003, 5].max
    # if (workfee<5)
    #   workfee=5
    # end

    #print ("buy money #{buymoney} \n")
    buytotal=buymoney+workfee
  end #def calculatebuymoney(buyentry)

  #计算单次卖出收回的金额。
  def calculateSellMoney(entry)
    sellPrice = entry[FieldCode::Price] || entry['price'] # get sell price.
    
    sellMoney= sellPrice * entry['amount'] # 卖出产生的金额。
    #sellMoney=entry['price']*entry[FieldCode::Amount] #卖出产生的金额。
        
    workfee=sellMoney*0.0003
        
    if (workfee<5)
      workfee=5
    end # if (workfee<5)
        
    flowerTax=sellMoney*0.001 #印花税。
        
    sellTotal=sellMoney-workfee-flowerTax #扣除手续费和印花税，得到收回的金额。
  end #def calculateSellMoney(entry) #计算收回的金额。
    
  #计算补仓效果
  def calculateFixEffect(holdPrice, moneyInput, holdAmount, fixLowPrice, fixHighPrice, expectedProfit) 
    baseTransaction={} #基本事务，已有的持仓信息
        
    baseTransaction['type']='buy' #买入
    baseTransaction['price']=holdPrice #买入价格
    baseTransaction['amount']=holdAmount #买入数量
        
        fixLowPriceScale=(fixLowPrice*100).to_i #最低价格放大后的值
        fixHighPriceScale=(fixHighPrice*100).to_i #最高价格放大后的值
        
        fixEffectList=[] #补仓效果条目列表
        
        fixPriceRangeScale= fixLowPriceScale .. (fixHighPriceScale+1) #构造，放大后的补仓价格范围
        
        fixPriceRangeScale.each do |currentFixPriceScale| # 一个个地计算
            currentFixPrice=currentFixPriceScale.to_f / 100.0 #计算出对应的补仓价格
            
            #构造事务列表：
            
            transactionListObject=[] #事务列表
            
            transactionListObject << baseTransaction #加入基本事务，已有的持仓事务
            
            
            currentFixAmount= ( ( moneyInput/currentFixPrice / 100 ).floor) * 100 #补仓数量
            
            puts("current fix price: #{currentFixPrice}, fix amount: #{currentFixAmount}") #Debug
            
            trialTransaction={} #要计算其补仓效果的事务对象
            trialTransaction['type']='buy' #买入
            trialTransaction['price']=currentFixPrice #买入价格
            trialTransaction['amount']=currentFixAmount #买入数量
            
            transactionListObject << trialTransaction #加入要进行尝试的事务对象
            
            stockJsonObject={} #整个事务列表JSON对象
            stockJsonObject['transactionList']=transactionListObject # 事务列表
            stockJsonObject['targetProfit']=expectedProfit #目标收益
            
            #序列化成JSON字符串：
            jsnWhlStr=Oj.dump(stockJsonObject) #格式化成JSON。
            
            #调用清仓价格计算方法：
            currentFixResult=calculateSellOutPrice(jsnWhlStr, expectedProfit) #计算当前补仓价格下产生的清仓价格
            
            #取出结果中的清仓价格：
            currentSellPrice=currentFixResult['sellPrice'] # 获取清仓价格
            
            #加入到结果中：
            currentFixEffectItem={} #当前补仓效果条目
            currentFixEffectItem['fixPrice']=currentFixPrice #补仓价格
            currentFixEffectItem['sellPrice']=currentSellPrice #清仓价格
            
            puts("sell price: #{currentSellPrice}") #Debug
            
            fixEffectList << currentFixEffectItem #加入到列表中
        end #fixPriceRangeScale.each do |currentFixPriceRange| #一个个地计算
        
        #返回结果：
        result={} #结果对象
        result['fixEffectList']=fixEffectList #加入补仓效果列表
        
        result #返回结果
    end #calculateFixEffect(holdPrice, moneyInput, holdAmount, fixLowPrice, fixHighPrice, expectedProfit) #计算补仓效果

     # 针对列表进行计算。计算成本、价格。
    def calculateSellOutPriceForTransactionListObject(transactionListObject, expectedProfit)
        #购买记录：
        buylist=[]

        # 卖出记录：
        sellList=[] #卖出记录。

        transactionListObject.each do |currentTransaction| # 一个个事务地处理
            currentType=currentTransaction['type'] #获取类型
            
            if (currentType=='buy') #买入
                currentbuyentry={}
                currentbuyentry['price']=currentTransaction['price']
                currentbuyentry['amount']=currentTransaction['amount']
                buylist << currentbuyentry
            elsif (currentType=='sell') #卖出
                sellList << currentTransaction
            else #冻结 Freeze
                buylist.clear #清空
                sellList.clear #清空
            end #if (currentType=='buy') #买入
        end #transactionListObject.each do |currentTransaction| #一个个事务地处理
        
        #计算买入列表中的数据：
        buytotal=0
        buyamount = 0

        buylist.each do |entry|
            currentbuymoney=calculatebuymoney(entry)
            buytotal=buytotal+currentbuymoney
            buyamount=buyamount+entry['amount']
        end

        #计算卖出列表中的数据：
        sellList.each do |entry|
            currentSellMoney=calculateSellMoney(entry) # 计算收回的金额。
            buytotal=buytotal-currentSellMoney #总成本中扣除收回的金额。
            buyamount=buyamount-entry['amount'] #总股票数量中扣除卖出的数量。
        end # sellList.each do |entry|


        print "buy total #{buytotal}\n"
        #print "buy amount #{buyamount}\n"

        buycost=0
        if (buyamount != 0)
            buycost=buytotal/buyamount
        end

#         print ("buy cost #{buycost}\n")

        #profit=stockJsonObject['targetProfit'] #获取目标收益
        profit=expectedProfit # 获取目标收益
        
        #puts("target profit: #{profit}") #Debug

        sellpure=buytotal+profit

        sellfee=[sellpure*0.0003,5].max

        selltotal=sellpure/(1-0.001)+sellfee

        #selltotal=(buytotal+profit)/(1-0.0003-0.001)
#         print "sell total #{selltotal}\n"

        sellprice=0 # 计算的卖出价
        normalsell=0 #舍入之后的卖出价
        actualselltotal=0 #剩余的持仓，应当卖得的总价钱
        actualprofit=0 #按照计算的价格卖出，实际得到的收益
        fixPrice=0 #补仓价格
        #         print ("Fix price: #{fixPrice}\n")
        fixNormal=0
        
        quitSellPure=0 #无赢利退出所需要的卖出总价
        quitSellFee=0 # 退出所花费的卖出手续费
        quitSellTotal=0 # 退出所需的卖出总价，算上了手续费和印花税
        quitSellPrice=0 #退出所需的卖出价格
        quitNormalSell=0 #退出所需的市场卖出价格
        actualQuitSellTotal=0 #退出时实际产生的卖出总价
        actualQuitProfit=0 #退出时产生的实际利润
        
        
        quitFixPrice=0 # 退出时补仓价格
        #         print("quit fix price: #{quitFixPrice}\n")
        quitFixNormal=0
        
        if (buyamount==0) #未持仓了
        else #还有持仓
            sellprice=selltotal/buyamount
            #         print "sell price #{sellprice}\n"
            normalsell=((sellprice*100).ceil)/100.0
            
            actualselltotal = normalsell * buyamount
            actualprofit=actualselltotal*(1-0.0003-0.001)-buytotal
            #         print "actual profit #{actualprofit}\n"
            
            fixPrice=buycost*2-sellprice #补仓价格
            #         print ("Fix price: #{fixPrice}\n")
            fixNormal=((fixPrice*100).floor)/100.0

            quitSellPure=buytotal #无赢利退出所需要的卖出总价
            quitSellFee=[quitSellPure*0.0003, 5].max #退出所花费的卖出手续费
            quitSellTotal=quitSellPure/(1-0.001)+quitSellFee #退出所需的卖出总价，算上了手续费和印花税
            quitSellPrice=quitSellTotal/buyamount #退出所需的卖出价格
            quitNormalSell=((quitSellPrice*100).ceil)/100.0 #退出所需的市场卖出价格
            actualQuitSellTotal=quitNormalSell*buyamount #退出时实际产生的卖出总价
            actualQuitProfit=actualQuitSellTotal*(1-0.0003-0.001)-buytotal # 退出时产生的实际利润

            quitFixPrice=buycost*2-quitSellPrice #退出时补仓价格
            #         print("quit fix price: #{quitFixPrice}\n")
            quitFixNormal=((quitFixPrice*100).floor)/100.0
            
        end #if (buyamount==0) #未持仓了

        resultObject={} # 结果对象

        resultObject['sellPrice']=normalsell #卖出价格
        resultObject['fixPrice']=fixNormal #补仓价格
        resultObject['quitSellPrice']=quitNormalSell # 退出卖出价格
        resultObject['holdPrice']=quitSellPrice #持仓成本
        resultObject['quitFixPrice']=quitFixNormal #退出补仓价格
        
        #resultObject['holdAmount']=buyamount # 持仓数量
        resultObject[FieldCode::HoldAmount]=buyamount # 持仓数量
        
        resultObject 
    end #calculateSellOutPriceForTransactionListObject(transactionListObject, expectedProfit) # 针对列表进行计算。
    
    #计算清仓价格
    def calculateSellOutPrice(transactionList, expectedProfit) 
        #构造购买记录列表和卖出记录列表：
        stockJsonObject=JSON.parse(transactionList) # 解析成JSON

        transactionListObject=stockJsonObject['transactionList'] #获取事务列表对象
        
        profit=stockJsonObject['targetProfit'] #获取目标收益

        resultObject=calculateSellOutPriceForTransactionListObject(transactionListObject, profit) # 针对列表进行计算。
        
        # 递归计算前面的历史交易记录对应的各个数据：
        subTransactionListObject=[] # 交易记录子列表。
        subResultList=[] # 子列表结果列表。
        
        transactionListObject.each do |currentTransaction|
            subTransactionListObject << currentTransaction # 加入子列表中。
            
            subResultObject=calculateSellOutPriceForTransactionListObject(subTransactionListObject, profit) # 计算出子列表对应的结果数据。
            
            subResultList << subResultObject # 加入子列表结果列表中。
        end
        
        resultObject['subResultList']=subResultList # 加入子列表结果列表。
        
        resultObject # 返回结果对象。
    end # calculateSellOutPrice(transactionList, expectedProfit) #计算清仓价格
    
    # 计算交易列表最终产生的收益
    def calculateProfit(transactionList) 
      #购买记录：
      # buylist=[]
         
      # 卖出记录：
      # sellList=[] #卖出记录。
      profit=0
        
      transactionList.reverse_each do |currentTransaction| #一个个事务地处理
        currentType=currentTransaction['type'] # 获取类型
            
        if (currentType== ValueCode::Buy) # 买入
          # buylist << currentTransaction
          
          currentbuymoney=calculatebuymoney(currentTransaction)
          profit = profit - currentbuymoney
          # buyamount=buyamount+currentTransaction['amount']
          
        elsif (currentType== ValueCode::Sell) #卖出
          if (currentTransaction['soFarProfit']) # Already calculated profit for this transaction and transactions before
            profit = profit + currentTransaction['soFarProfit'] # Use existing profit value as the profit of the transactions before.
            
            break # No need to re calculate the transactions calculated before.
          else # Not calcuated before
            # sellList << currentTransaction
            currentSellMoney=calculateSellMoney(currentTransaction) #计算收回的金额。
            profit = profit + currentSellMoney #总成本中扣除收回的金额。
                
            # buyamount=buyamount-entry['amount'] # 总股票数量中扣除卖出的数量。
          end # if (currentTransaction['soFarProfit']) # Already calculated profit for this transaction and transactions before
        else # Other type
          puts "Unknown type: #{currentType} #{__LINE__}" # Report error
        end #if (currentType=='buy') #买入
      end # transactionListObject.each do |currentTransaction| #一个个事务地处理
        
      #计算买入列表中的数据：
      # buyamount=0
        
      # buylist.each do |entry|
      #   currentbuymoney=calculatebuymoney(entry)
      #   profit = profit - currentbuymoney
      #   buyamount=buyamount+entry['amount']
      # end
        
      #计算卖出列表中的数据：
#       sellList.each do |entry|
#         currentSellMoney=calculateSellMoney(entry) #计算收回的金额。
#         profit = profit + currentSellMoney #总成本中扣除收回的金额。
#             
#         buyamount=buyamount-entry['amount'] # 总股票数量中扣除卖出的数量。
#         #buyamount=buyamount-entry[FieldCode::Amount] # 总股票数量中扣除卖出的数量。
#       end # sellList.each do |entry|

      profit
    end #calculateProfit(transactionList) #计算交易列表最终产生的收益
end # class StockCostCalculator
