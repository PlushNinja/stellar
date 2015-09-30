#encoding: utf-8

class User < ActiveRecord::Base

  # Adds `creatable_by?(user)`, etc.
  include Authority::UserAbilities
  include Authority::Abilities
  resourcify
  rolify

  # Include default devise modules. Others available are:
  # :registerable, :recoverable, :confirmable, :lockable,
  # :timeoutable and :omniauthable
  devise :database_authenticatable, :rememberable, :trackable, :validatable

  #---
  # Users are restricted to interacting with only one store.
  belongs_to :store

  has_many :orders

  scope :by_role, -> (role_name) { joins(:roles).where(roles: {name: role_name}) }
  scope :non_guests, -> { joins(:roles).where.not(roles: {name: 'guest'}) }

  #---
  validates :name, presence: true

  #---
  # A user's shopping cart is technically an order singleton in the scope of
  # current store, the one and only order that's not been ordered yet.
  def shopping_cart(store)
    orders.by_store(store).unordered.first ||
      orders.create(
        store: store,
        order_type: store.default_order_type,
        customer_name: is_guest? ? nil : name,
        customer_email: is_guest? ? nil : email
      )
  end

  # Superiority over another user is decided on the pecking order
  # of their highest ranked roles.
  def superior_to?(user)
    roles.first.id < user.roles.first.id
  end

  def grantable_role_options
    Role.all.map { |r| [r.to_s, r.id] }
  end

  def role_names
    roles.map { |r| r.to_s }
  end

  def to_s
    "#{name} <#{email}>"
  end
end
