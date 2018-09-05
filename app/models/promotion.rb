#encoding: utf-8
#
# Promotions of one or more promoted items that run from first_date
# to last_date. The business logic of the promotion is defined by its
# promotion handler that is created on the creation of the promotion.
#
class Promotion < ActiveRecord::Base

  resourcify
  include Authority::Abilities
  include Trackable
  include Pictureable
  include Pageable
  include FriendlyId
  friendly_id :slugger, use: [:slugged, :scoped, :history], scope: :store

  #---
  belongs_to :store
  belongs_to :group, required: true

  has_many :promoted_items, dependent: :destroy
  has_many :products, through: :promoted_items
  has_one :promotion_handler, dependent: :destroy
  accepts_nested_attributes_for :promotion_handler

  scope :live, -> { where(live: true) }

  #---
  validates :name, presence: true
  validates_associated :promoted_items, on: :update

  after_save :touch_products
  after_save :reset_live_status!
  after_save :schedule_activation
  before_destroy :touch_products

  #---
  # These attributes allow adding products and categories en masse
  # through a string of comma-separated ids.
  attr_accessor :product_ids_string, :category_ids_string

  #---
  # When a promotion is created, its promotion handler type specifies one
  # of the PromotionHandler subclasses as string. An object of this type is
  # created and associated with the promotion.
  def self.handler_types
    [
      'PromotionHandler::BulkDiscount',
      'PromotionHandler::BundlePricing',
      'PromotionHandler::FreebieBundle',
      'PromotionHandler::Vanilla',
    ]
  end

  #---
  delegate :description, to: :promotion_handler
  delegate :editable_prices?, to: :promotion_handler

  # Applies this promotion to the given order by calling the promotion
  # handler with the matching items.
  def apply!(order)
    promotion_handler.apply!(order, matching_items(order))
  end

  # Finds the promoted item matching given order item.
  def item_from_order_item(order_item)
    promoted_items.find_by(product_id: order_item.product_id)
  end

  def available_categories
    store.categories.order(:lft)
  end

  def active?
    (first_date.nil? || !first_date.future?) &&
    (last_date.nil? || !last_date.past?)
  end

  def slugger
    [:name, [:name, :id]]
  end

  def should_generate_new_friendly_id?
    name_changed? || super
  end

  # Exact time the promotion is activated.
  def activate_at
    first_date.present? && first_date.midnight
  end

  # Exact time the promotion is deactivated.
  def deactivate_at
    last_date.present? && last_date.tomorrow.midnight
  end

  def to_s
    name
  end

  def reset_live_status!
    update_columns(live: active?)
    touch
    true
  end

  def touch_products
    transaction do
      products.each do |product|
        product.touch
      end
    end
  end

  private
    # Takes an order object and returns order items that match this promotion.
    def matching_items(order)
      order.order_items.where(product_id: promoted_items.pluck(:product_id))
    end

    def schedule_activation
      if activate_at && activate_at.future?
        PromotionActivationJob.set(wait_until: activate_at).perform_later(self)
      end
      if deactivate_at && deactivate_at.future?
        PromotionActivationJob.set(wait_until: deactivate_at).perform_later(self)
      end
    end
end
