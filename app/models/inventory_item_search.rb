#encoding: utf-8

require 'searchlight/adapters/action_view'

class InventoryItemSearch < Searchlight::Search

  include Searchlight::Adapters::ActionView

  #---
  def base_query
    InventoryItem.includes(:product).order('products.title', 'products.subtitle')
  end

  def search_store
    query.joins(:inventory).where(inventories: {store_id: store})
  end

  def search_code
    query.where(code: code)
  end

  def search_inventory_id
    query.where(inventory_id: inventory_id)
  end

  def search_product_id
    query.where(product_id: product_id)
  end

  def search_live
    return query if empty?(live)
    query.where(products: {live: checked?(live)})
  end
end
