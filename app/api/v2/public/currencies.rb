# encoding: UTF-8
# frozen_string_literal: true

module API
  module V2
    module Public
      class Currencies < Grape::API

        desc 'Get a currency' do
          success Entities::Currency
        end
        params do
          requires :id,
                   type: String,
                   values: { value: -> { Currency.enabled.codes(bothcase: true) }, message: 'public.currency.doesnt_exist'},
                   desc: -> { API::V2::Entities::Currency.documentation[:id][:desc] }
        end
        get '/currencies/:id' do
          present Currency.find(params[:id]), with: API::V2::Entities::Currency
        end

        desc 'Get list of currencies',
          is_array: true,
          success: Entities::Currency
        params do
          optional :type,
                   type: String,
                   values: { value: %w[fiat coin], message: 'public.currency.invalid_type' },
                   desc: -> { API::V2::Entities::Currency.documentation[:type][:desc] }
        end
        get '/currencies' do
          currencies = Rails.cache.fetch('currencies') do
            if params[:type] == 'coin'
              Currency.enabled.where(type: params[:type]).includes(:blockchain)
            elsif params[:type] == 'fiat'
              Currency.enabled.here(type: params[:type]).to_json
            else
              Currency.enabled.to_json
            end
          end

          present currencies.ordered, with: API::V2::Entities::Currency
        end
      end
    end
  end
end
