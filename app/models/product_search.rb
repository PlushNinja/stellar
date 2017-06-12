#encoding: utf-8

require 'searchlight/adapters/action_view'

class ProductSearch < Searchlight::Search

  include Searchlight::Adapters::ActionView

  # Defines a search method for a property. Using subselects
  # makes it possible to match multiple properties at the same time.
  def self.define_search_method(property)
    key = property.sluggify
    define_method("search_#{key}") do
      query.where("EXISTS (SELECT 1 FROM product_properties WHERE product_id = products.id AND property_id = #{property.id} AND value IN (?))", send(key))
    end
  end

  # Defines search methods for all existing properties. When a property
  # is created or modified, call #define_search_method on it.
  Property.searchable.each do |property|
    define_search_method(property)
  end

  #---
  def base_query
    Product.includes(:categories)
  end

  def search_store_id
    query.where(store_id: store_id)
  end

  def search_vendor_id
    query.where(vendor_id: vendor_id)
  end

  def search_code
    query.where('products.code LIKE ? OR products.customer_code LIKE ?', "#{code}%", "#{code}%")
  end

  def search_keyword
    query.where("CONCAT_WS(' ', products.code, products.customer_code, products.title, products.subtitle) LIKE ?", "%#{keyword}%")
  end

  def search_purposes
    query.where(purpose: Product.purposes.slice(*purposes).values)
  end

  def search_categories
    query.where(categories: {id: categories})
  end

  def search_live
    return query if empty?(live)
    query.where(live: checked?(live))
  end

  def search_price_min
    query.where('retail_price_cents >= ?', price_min.to_money.cents)
  end

  def search_price_max
    query.where('retail_price_cents <= ?', price_max.to_money.cents)
  end

  def search_exclusions
    query.where.not(id: exclusions)
  end
end
