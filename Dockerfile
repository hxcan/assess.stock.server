FROM ruby:3.0.5

RUN bundle config --global fronzen 1

WORKDIR /usr/src/app

EXPOSE 11244

CMD [ "ruby", "./AssessStockServer.cache.rb" ]

COPY Gemfile Gemfile.lock ./

RUN bundle install

COPY StockDataTools ./StockDataTools/

COPY AssessStock ./AssessStock/

COPY StockCostCalculatorRuby ./StockCostCalculatorRuby/

COPY StockHistoryzzapun ./StockHistoryzzapun/

COPY EncryptionManager ./EncryptionManager/

COPY FieldCode.ty ./FieldCode.ty/

COPY *.rb ./
