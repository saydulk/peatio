# encoding: UTF-8
# frozen_string_literal: true

module Abilities
  class Admin
    include CanCan::Ability

    def initialize
      can :read, Order
      can :read, Trade
      can :read, Member
      can :read, Job

      can :manage, Deposit
      can :manage, Withdraw

      can :manage, Operations::Account
      can :manage, Operations::Asset
      can :manage, Operations::Expense
      can :manage, Operations::Liability
      can :manage, Operations::Revenue

      can :manage, Market
      can :manage, Currency
      can :manage, Blockchain
      can :manage, Wallet

      can :read, Account
      can :read, PaymentAddress
    end
  end
end
