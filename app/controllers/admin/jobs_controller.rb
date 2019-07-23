# encoding: UTF-8
# frozen_string_literal: true

module Admin
  class JobsController < BaseController
    skip_load_and_authorize_resource

    def index
      @jobs = Job.page(params[:page]).per(30)
    end
  end
end
