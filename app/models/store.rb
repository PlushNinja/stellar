#encoding: utf-8

class Store < ActiveRecord::Base

  store :settings, accessors: [
    :locale, :theme, :menu_title,
    :allow_shopping, :b2b_sales, :admit_guests,
    :shipping_cost_product_id, :free_shipping_at,
    :tracking_code
  ], coder: JSON

  resourcify
  include Authority::Abilities
  include Imageable

  #---
  after_create :assign_slug

  #---
  has_many :categories
  has_many :products
  has_many :custom_attributes
  has_many :orders
  has_many :users
  has_many :pages
  has_and_belongs_to_many :inventories
  has_many :order_types, through: :inventories
  has_many :promotions

  scope :all_except, -> (this) { where.not(id: this) }

  #---
  validates :name, presence: true
  validates :erp_number, numericality: true, allow_blank: true

  #---
  # Performs an inventory valuation of items in the shipping inventory.
  def inventory_valuation
    items = inventory_for(:shipping).inventory_items
              .for_products(products.categorized)
    [items, items.map { |item| item.total_value }.sum]
  end

  # Finds the first inventory by purpose.
  def inventory_for(purpose)
    inventories.by_purpose(purpose)
  end

  def category_options
    categories.map { |c| [c.name, c.id] }
  end

  def user_options
    users.map { |u| [u.to_s, u.id] }
  end

  def page_options
    pages.map { |p| [p.to_s, p.id] }
  end

  # Finds the shipping cost product manually due to having
  # shipping_cost_product_id a setting instead of a real relation.
  def shipping_cost_product
    if shipping_cost_product_id.present?
      Product.find(shipping_cost_product_id)
    else
      nil
    end
  end

  # Defines accessors to boolean settings not generated by Rails.
  def allow_shopping?; allow_shopping; end
  def admit_guests?; admit_guests; end
  def b2b_sales?; b2b_sales; end

  def allow_shopping=(value); super(value == '1'); end
  def admit_guests=(value); super(value == '1'); end
  def b2b_sales=(value); super(value == '1'); end

  def correspondents
    users.with_role(:correspondence)
  end

  # How to title the store in navigation menus.
  # The given string undergoes I18n before output.
  def menu_title
    super || 'store'
  end

  def to_s
    name
  end

  private
    def assign_slug
      taken_slugs = Store.all_except(self).map(&:slug)
      len = 3
      unique_slug = "#{name}#{id}#{Time.now.to_i}"
        .parameterize.underscore.mb_chars.downcase
      begin
        slug = unique_slug[0, len]
        len += 1
      end while taken_slugs.include?(slug)
      update(slug: slug)
    end
end
