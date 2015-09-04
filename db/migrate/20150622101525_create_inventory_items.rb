class CreateInventoryItems < ActiveRecord::Migration
  def change
    create_table :inventory_items do |t|
      t.belongs_to :inventory, null: false, index: true
      t.belongs_to :store, null: false, index: true
      t.belongs_to :product, null: false, index: true
      t.string :shelf
      t.integer :amount
      t.decimal :value, precision: 8, scale: 2

      t.timestamps null: false
    end
  end
end
