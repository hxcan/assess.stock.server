#!/usr/bin/env ruby

# frozen_string_literal: true

$stdout.sync = true 

this_dir = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH.unshift(this_dir) unless $LOAD_PATH.include?(this_dir)

require 'eventmachine'
require 'date'
require 'cbor'
require 'websocket-eventmachine-server'
require 'stackprof'

require './FieldCode.ty/FieldCode.h' # FieldCode
require './FieldCode.ty/FunctionCode.h' # FunctionCode
require './FieldCode.ty/ValueCode.ui' # ValueCode
require './AssessStock/StockAssessor' #StockAssessor
require './AssessStock/TransactionListCache' # TransactionListCache
require './AssessStock/PriceRateGeneralEvolveHandler' # PriceRateGeneralEvolveHandler
require './AssessStock/RuleType' # RuleType
require './AssessStock/StockRuleFactory' # StockRuleFactory
require './AssessStock/StockRule' # StockRule
require './AssessStock/StockRule2' # StockRule2
require './AssessStock/StockRule1' # StockRule1
require './AssessStock/StockRule3' # StockRule3
require './AssessStock/StockRule4' # StockRule4
require './AssessStock/StockRule5' # StockRule5
require './AssessStock/StockRule6' # StockRule6
require './StockHistoryzzapun/StockHistoryzzapum' #StockHistoryReporter
require './StockHistoryzzapun/StockCodeAliasNotExist.i' # StockCodeAliasNotExist
require './StockCostCalculatorRuby/StockCostCalculator' # StockCostCalculator
require './EncryptionManager/EncryptionManager' # EncryptionManager
require './Message.Handler.zzaqmy' #MessageHandler

class UDPHandler < EM::Connection
    def receive_data(command)
        #log("Received #{command}")
#         send_data(command)
        
        messageHandler=MessageHandler.new #创建消息处理器
        
        resultMessage=messageHandler.receive_data(command) #处理消息
        
        send_data(resultMessage) #回复消息 
    end
    
    def log(message)
      puts("#{DateTime.now.to_s} : #{message}")
    end
end

$ws=nil #连接对象。

$wsList=[] #网页套接字列表

$messageHandler={} #消息处理器
$requestCount=0

def startWebSocketServer
  $messageHandler=MessageHandler.new #创建消息处理器

  WebSocket::EventMachine::Server.start(:host => "0.0.0.0", :port => 11244) do |ws|
    $wsList << ws #记录连接对象。
    $ws=ws
        
    ws.onopen do #收到新连接。
      puts "#{__LINE__}, #{self.class.name}, new connection: #{ws}" # Debug.
    end #ws.onopen do #收到新连接。

    ws.onmessage do |msg, type| #收到消息。
      $requestCount=$requestCount+1
      #if $requestCount>=2000
      #else
        resultMessage=$messageHandler.receive_data(msg) #处理消息

        ws.send(resultMessage, :type => :binary) #发送一号宏的JSON内容。
      #end
    end #ws.onmessage do |msg, type| #收到消息。

    ws.onclose do #连接断开。
      # EM.stop # Quit
    end #ws.onclose do #连接断开。
  end #WebSocket::EventMachine::Server.start(:host => "0.0.0.0", :port => 8080) do |ws|
end #def startWebSocketServer

#要在 AssessStockServer.emscripten 目录下运行

def startEventLoop
  # begin
    EM.run do 
      EM.open_datagram_socket('0.0.0.0', 12091, UDPHandler)
        
      startWebSocketServer #启动网页套接字服务器。
    end
  # rescue Interrupt
  #   EM.stop
  # end
    
  # EM.error_handler { EM.stop }
end # def startEventLoop

startEventLoop

def startStackProf
  StackProf.run(mode: :cpu, out: '/Ibotex/Temp.-dir/androidasasoundbox/.hg/cache/Linux_tts_online1227_52fc7513/bin/ise_cn/cn.vr4p.vr4pmovieplayer_2.2.1_20201/assets/web/2022_05_30_21_11_16_fdb82a229cae412b9fea0f3667181f07/file/ca6ed053-7bce-4c54-833f-b1c30a99c36a.qingguan_4_foxiang/qingguan_4_foxiang.atlas') do
    startEventLoop
  end # StackProf.run(mode: :cpu, out: '') do
end # def startStackProf

# startStackProf
