#encoding: utf-8

class Store < ActiveRecord::Base

  resourcify
  include Authority::Abilities
  include Imageable

  after_create :assign_slug

  belongs_to :contact_person, class_name: 'User'
  has_many :categories
  has_many :products
  has_many :orders
  has_many :users
  has_many :pages
  has_many :inventories
  def inventories
    local_inventory? ? super : Inventory.global
  end

  scope :all_except, -> (this) { where.not(id: this) }

  validates :name, presence: true
  validates :erp_number, numericality: true, allow_blank: true


  # Performs a stock lookup on a product. Returns an array
  # of inventory items per inventory, adjusted by orders.
  def stock_lookup(code)
    stock = [].tap do |stock|
      inventories.each do |inventory|
        if (item = inventory.lookup(code))
          stock << OrderItem.adjust!(item)
        end
      end
    end
  end

  # Finds the first inventory by purpose.
  def inventory_for(purpose)
    inventories.by_purpose(purpose)
  end

  def category_options
    categories.map { |c| [c.name, c.id] }
  end

  def order_type_options
    options = [].tap do |options|
      inventories.each do |i|
        i.order_types.each do |o|
          options << [o.name, o.id, {class: i.purpose}]
        end
      end
    end
  end

  def user_options
    users.map { |u| [u.to_s, u.id] }
  end

  def page_options
    pages.map { |p| [p.to_s, p.id] }
  end

  def to_s
    new_record? ? 'New store' : name
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
      update_attributes(slug: slug)
    end
end
