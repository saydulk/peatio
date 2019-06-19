# encoding: UTF-8
# frozen_string_literal: true

require File.join(ENV.fetch("RAILS_ROOT"), "config", "environment")

require "peatio/mq/events"

$running = true
Signal.trap(:TERM) { $running = false }

while $running
  begin
    tickers = {}

    # NOTE: Turn off push notifications for disabled markets.
    Market.enabled.each do |market|
      state = Global[market.id]

      Peatio::MQ::Events.publish("public", market.id, "update", {
        asks: state.asks[0,300],
        bids: state.bids[0,300],
      })

      tickers[market.id] = market.unit_info.merge(state.ticker)
    end

    Peatio::MQ::Events.publish("public", "global", "tickers", tickers)

    tickers.clear

  rescue Mysql2::Error::ConnectionError => e
    begin
      Rails.logger.warn { 'Try recconecting to db.' }
      retries ||= 0
      ActiveRecord::Base.connection.reconnect!
    rescue
      sleep_time = (retries += 1)**1.5
      Rails.logger.warn { "#{retries} retry. Waiting for connection #{sleep_time} seconds..." }
      sleep sleep_time
      retries < 5 ? retry : raise(e) # will retry the reconnect
    else
      Rails.logger.warn { 'Connection established' }
      retries = 0
    end
  rescue ActiveRecord::StatementInvalid => e
    if e.cause.is_a?(Mysql2::Error::ConnectionError)
      begin
        Rails.logger.warn { 'Try recconecting to db.' }
        retries ||= 0
        ActiveRecord::Base.connection.reconnect!
      rescue
        sleep_time = (retries += 1)**1.5
        Rails.logger.warn { "#{retries} retry. Waiting for connection #{sleep_time} seconds..." }
        sleep sleep_time
        retries < 5 ? retry : raise(e) # will retry the reconnect
      else
        Rails.logger.warn { 'Connection established' }
        retries = 0
      end
    end
  rescue => e
    report_exception(e)
  end
  Kernel.sleep 5
end
