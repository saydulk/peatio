# encoding: UTF-8
# frozen_string_literal: true
require 'csv'

namespace :import do
  # Required fields for import users:
  # - AccountId with format (7890)
  # - email
  #
  # Make sure that you create required currency
  # Usage:
  # For import users: -> bundle exec rake import:users['file_name.csv']

  desc 'Load members from csv file.'
  task :users, [:config_load_path] => [:environment] do |_, args|
    csv_table = File.read(Rails.root.join(args[:config_load_path]))
    errors_users_file = File.open("errors_users_file.txt", "w")
    count = 0
    CSV.parse(csv_table, headers: true).map do |row|
      composed_uid = "ID" + (1000000000 + row['AccountId'].to_i).to_s
      email = row['Email']
      level = row.fetch('level', 0)
      role = row.fetch('role', 'member')
      state = row.fetch('state', 'active')
      ActiveRecord::Base.transaction do
        Member.create!(uid: composed_uid, email: email, level: level, role: role, state: state)
        count += 1
      end
    rescue => e
      message = { error: e.message, email: row['Email'], account_id: row['AccountId'], composed_uid: composed_uid }
      errors_users_file.write(message.to_yaml + "\n")
    end
    errors_users_file.close
    Kernel.puts "Created #{count} members"
  end

  # Required fields for import accounts balances:
  # - AccountId with format (7890)
  # - ProductSymbol as currency_id
  # - Amount
  # Make sure that you create required currency
  # Usage:
  # For import account balances: -> bundle exec rake import:accounts['file_name.csv']

  desc 'Load accounts balances from csv file.'
  task :accounts, [:config_load_path] => [:environment] do |_, args|
    csv_table = File.read(Rails.root.join(args[:config_load_path]))
    errors_accounts_file = File.open("errors_accounts_file.txt", "w")
    count = 0
    CSV.parse(csv_table, headers: true).map do |row|
      composed_uid = 'ID' + (1_000_000_000 + row['AccountId'].to_i).to_s
      member = Member.find_by_uid!(composed_uid)
      currency = Currency.find(row['ProductSymbol'])
      account = Account.find_by!(member: member, currency_id: currency)
      amount = row['Amount'].to_d
      next if amount.zero?

      asset_code = currency.coin? ? 102 : 101
      liability_code = currency.coin? ? 202 : 201
      ActiveRecord::Base.transaction do
        Operations::Asset.create!(code: asset_code, currency_id: currency.id, credit: amount)
        Operations::Liability.create!(code: liability_code, currency_id: currency.id, member_id: member.id, credit: amount) 
        account&.update!(balance: amount)
        count += 1
      end
    rescue => e
      message = { error: e.message, accoutn_id: row['AccountId'], composed_uid: composed_uid }
      errors_accounts_file.write(message.to_yaml + "\n")
    end
    errors_accounts_file.close
    Kernel.puts "Accounts updated #{count}"
  end

  desc 'Check existing currencies for positive balances'
  task :check_currencies, [:config_load_path] => [:environment] do |_, args|
    csv_table = File.read(Rails.root.join(args[:config_load_path]))
    errors_currencies_file = File.open("errors_currencies_file.txt", "w")
    count = 0
    CSV.parse(csv_table, headers: true).map do |row|
      count += 1
      amount = row['Amount'].to_d
      next if amount.zero?

      composed_uid = 'ID' + (1_000_000_000 + row['AccountId'].to_i).to_s
      Member.find_by_uid!(composed_uid)
      Currency.find(row['ProductSymbol'])
    rescue => e
      message = { error: e.message, accoutn_id: row['AccountId'], composed_uid: composed_uid, amount: row['Amount'].to_f }
      errors_currencies_file.write(message.to_yaml + "\n")
    end
    errors_currencies_file.close
    Kernel.puts "Accounts processed #{count}"
  end
end
