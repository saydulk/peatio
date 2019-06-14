# encoding: UTF-8
# frozen_string_literal: true

require File.join(ENV.fetch('RAILS_ROOT'), 'config', 'environment')

running = true
Signal.trap(:TERM) { running = false }

while running
  begin
  Blockchain.active.tap do |blockchains|
    if ENV.key?('BLOCKCHAINS')
      blockchain_keys = ENV.fetch('BLOCKCHAINS').split(',').map(&:squish).reject(&:blank?)
      blockchains.where!(key: blockchain_keys)
    end
  end.find_each do |bc|

    break unless running
    Rails.logger.info { "Processing #{bc.name} blocks." }

    blockchain = BlockchainService.new(bc)
    latest_block = blockchain.latest_block_number

    # Don't start process if we didn't receive new blocks.
    if bc.height + bc.min_confirmations >= latest_block
      Rails.logger.info { "Skip synchronization. No new blocks detected height: #{bc.height}, latest_block: #{latest_block}" }
      next
    end

    from_block   = bc.height || 0
    to_block     = [latest_block, from_block + bc.step].min
    (from_block..to_block).each do |block_id|

      Rails.logger.info { "Started processing #{bc.key} block number #{block_id}." }

      block_json = blockchain.process_block(block_id)
      Rails.logger.info { "Fetch #{block_json.transactions.count} transactions in block number #{block_id}." }
      Rails.logger.info { "Finished processing #{bc.key} block number #{block_id}." }
    end
    Rails.logger.info { "Finished processing #{bc.name} blocks." }
  end
  rescue Mysql2::Error::ConnectionError => e
    begin
      Rails.logger.info { 'Try recconecting to db.' }
      retries ||= 0
      ActiveRecord::Base.connection.reconnect!
    rescue
      sleep_time = (retries += 1)**1.5
      Rails.logger.info { "#{retries} retry. Waiting for connection #{sleep_time} seconds..." }
      sleep sleep_time
      retries < 5 ? retry : raise(e) # will retry the reconnect
    else
      Rails.logger.info { 'Connection established' }
      retries = 0
    end
  rescue ActiveRecord::StatementInvalid => e
    if e.cause.is_a?(Mysql2::Error::ConnectionError)
      begin
        Rails.logger.info { 'Try recconecting to db.' }
        retries ||= 0
        ActiveRecord::Base.connection.reconnect!
      rescue
        sleep_time = (retries += 1)**1.5
        Rails.logger.info { "#{retries} retry. Waiting for connection #{sleep_time} seconds..." }
        sleep sleep_time
        retries < 5 ? retry : raise(e) # will retry the reconnect
      else
        Rails.logger.info { 'Connection established' }
        retries = 0
      end
    end
  rescue => e
    report_exception(e)
  end
  Kernel.sleep 5
end
