# encoding: UTF-8
# frozen_string_literal: true

require File.join(ENV.fetch('RAILS_ROOT'), 'config', 'environment')

running = true
Signal.trap(:TERM) { running = false }

while running
  Blockchain.where(status: :active).tap do |blockchains|
    if ENV.key?('BLOCKCHAINS')
      blockchain_keys = ENV.fetch('BLOCKCHAINS').split(',').map(&:squish).reject(&:blank?)
      blockchains.where!(key: blockchain_keys)
    end
  end.find_each do |bc|
    break unless running

    Rails.logger.info { "Processing #{bc.name} blocks." }

    BlockchainService[bc.key].process_blockchain

    Rails.logger.info { "Finished processing #{bc.name} blocks." }
  rescue => e
    report_exception(e)
  end
  Kernel.sleep 5
end
