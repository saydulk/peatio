# encoding: UTF-8
# frozen_string_literal: true

class Job < ApplicationRecord
  STATES = %i[created succeed failed].freeze

  validates :state, inclusion: { in: STATES }

  def failed?
    state == 'failed'
  end

  def succeed?
    state == 'succeed'
  end
end

# == Schema Information
# Schema version: 20190719134706
#
# Table name: jobs
#
#  id          :bigint           not null, primary key
#  state       :string(30)       default("created"), not null
#  rows        :integer          default(0), not null
#  description :string(255)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
