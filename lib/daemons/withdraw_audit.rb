# encoding: UTF-8
# frozen_string_literal: true

require File.join(ENV.fetch('RAILS_ROOT'), 'config', 'environment')

$running = true
Signal.trap("TERM") do
  $running = false
end

while($running) do
  begin
    Withdraw.submitted.each do |withdraw|
      withdraw.audit!
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
  rescue
    puts "Error on withdraw audit: #{$!}"
    puts $!.backtrace.join("\n")
  end
  sleep 5
end
