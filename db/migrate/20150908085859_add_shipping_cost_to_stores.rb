class AddShippingCostToStores < ActiveRecord::Migration
  def change
    add_column :stores, :shipping_cost, :decimal, precision: 8, scale: 2,
      after: :admit_guests
    add_column :stores, :free_shipping_at, :decimal, precision: 8, scale: 2,
      after: :shipping_cost
  end
end
