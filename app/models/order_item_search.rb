#encoding: utf-8

require 'searchlight/adapters/action_view'

class OrderItemSearch < Searchlight::Search

  include Searchlight::Adapters::ActionView

  def base_query
    OrderItem.joins(:order).merge(Order.concluded)
      .reorder('orders.completed_at DESC')
  end

  def search_store_id
    query.where(orders: {store_id: store_id})
  end

  def search_since_date
    query.where('DATE(orders.completed_at) >= ?', since_date)
  end

  def search_until_date
    query.where('DATE(orders.completed_at) <= ?', until_date)
  end
end
