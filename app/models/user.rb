class User < ApplicationRecord

  # Adds `creatable_by?(user)`, etc.
  include Authority::UserAbilities
  include Authority::Abilities
  include Trackable
  resourcify
  rolify

  # Include default devise modules. Others available are:
  # :registerable, :recoverable, :confirmable, :lockable,
  # :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable, :confirmable, :recoverable, :rememberable, :trackable

  #---
  # Users may belong to any number of groups to be part of stores.
  has_and_belongs_to_many :groups
  has_many :stores, through: :groups

  has_and_belongs_to_many :favorite_products, -> { distinct }, class_name: 'Product'

  has_many :orders, dependent: :destroy
  has_many :customer_orders, class_name: 'Order', foreign_key: :customer_id, inverse_of: :customer

  # Order types from outgoing orders. See #existing_order_types below.
  has_many :order_types, -> { joins(:source) }, through: :orders

  has_many :performed_activities, class_name: 'Activity', foreign_key: :user_id

  default_scope { order(:name) }

  scope :with_activities, -> { joins(:performed_activities).reorder(:name).distinct }

  #---
  validates :email, presence: true, uniqueness: true
  validates :name, presence: true, on: :update
  validates :password, presence: true, if: :password_required?
  validates :password, confirmation: true

  #---
  # Generates a guest user visiting at hostname.
  def self.generate_guest!(hostname)
    uuid = SecureRandom.uuid
    guest = User.new(
      name: uuid,
      email: "#{uuid}@#{hostname}"
    )
    guest.skip_confirmation!
    guest.save!
    guest
  end

  #---
  # A user's shopping cart is the first incomplete order at given store.
  def shopping_cart(store, store_portal, group)
    cart = orders.at(store).incomplete.first
    return cart unless cart.nil?

    cart = orders.at(store).build(
      billing_group: group,
      shipping_group: group,
      inventory: store.default_inventory,
      store_portal: store_portal,
      includes_tax: group.price_tax_included?
    )
    cart.save!
    cart
  end

  # Order types seen in the user's set of completed orders.
  def existing_order_types(store)
    order_types.merge(Order.complete).where(orders: {store: store}).distinct
  end

  # Roles that a user manager may grant to other users. The superuser
  # may promote others to superusers.
  def grantable_roles
    roles = Role.available_roles
    has_cached_role?(:superuser) ? roles : roles - ['superuser']
  end

  # Finds the group this user belongs to at the given store.
  # Returns nil if the user is a guest.
  def group(store)
    groups.find_by(store: store)
  end

  def guest?(store)
    group(store).nil?
  end

  # The effective group is the user's own group, and
  # if none exists, the default group at the store.
  def effective_group(store)
    group(store) || store.default_group
  end

  def to_s
    "#{name} <#{email}>"
  end

  def require_password?
    encrypted_password.blank?
  end

  protected
    def password_required?
      persisted? && (
        encrypted_password.nil? ||
        password.present? ||
        password_confirmation.present?
      )
    end
end
