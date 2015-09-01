#encoding: utf-8

class Category < ActiveRecord::Base

  resourcify
  include Authority::Abilities
  include Imageable
  include Reorderable

  #---
  belongs_to :store
  belongs_to :parent_category, class_name: 'Category'
  has_many :sub_categories, class_name: 'Category', foreign_key: :parent_category_id
  has_many :products

  #---
  validates :name, presence: true

  #---
  def to_s
    name
  end
end
