#encoding: utf-8

module ShippingGateway

  class Letter
    include ActiveModel::Model

    attr_accessor :order

    def initialize(attributes = {})
      super
      raise ArgumentError if order.nil?
    end

    def to_partial_path
      'shipping_gateway/letter'
    end
  end
end
