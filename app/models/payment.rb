#encoding: utf-8

class Payment < ApplicationRecord

  monetize :amount_cents

  #---
  belongs_to :order

  default_scope { order(created_at: :desc) }

  #---
  def self.available_gateways
    %w{None Paybyway}
  end

  #---
  def to_s
    number
  end
end
