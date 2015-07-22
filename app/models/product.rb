#encoding: utf-8

class Product < ActiveRecord::Base

  resourcify
  include Authority::Abilities
  include Imageable
  include Reorderable

  belongs_to :store
  belongs_to :category
  has_many :inventory_items

  has_many :relationships, -> (product) {
    joins(:product).where(products: {store_id: product.store_id})
  }, foreign_key: :parent_code, primary_key: :code

  has_many :components, through: :relationships, class_name: 'Product', source: :product

  scope :categorized, -> { where.not(category_id: nil) }
  scope :uncategorized, -> { where(category_id: nil) }


  validates :store_id, presence: true
  validates :code, presence: true
  validates :title, presence: true


  def to_s
    new_record? ? 'New product' : title
  end
end
