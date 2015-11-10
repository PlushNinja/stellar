#encoding: utf-8

class ApplicationController < ActionController::Base

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  #---
  before_action :load_pages
  before_action :set_locale
  after_filter :prepare_unobtrusive_flash

  #---
  # Product filtering is available when a category is loaded.
  def filters_available?
    @category.present?
  end
  helper_method :filters_available?

  # Authenticate user, but skip authentication
  # if the current store admits guests.
  def authenticate_user_or_skip!
    return true if current_store.admit_guests?
    authenticate_user!
  end

  # Send the user back where she came from if not authorized.
  def authority_forbidden(error)
    Rails.logger.warn(error.message)
    redirect_to request.referrer.presence || root_path,
      alert: 'You are not authorized to complete that action.'
  end

  # Find the guest user stored in session, or create it.
  def guest_user
    @cached_guest ||= User.find(session[:guest_user_id] ||= create_guest_user.id)
  end

  # The methods below are for convenience and to cache often repeated
  # database queries on current user and her roles.
  helper_method :current_store, :shopping_cart, :can_shop?, :can_see_pricing?, :can_see_stock?, :can_manage?, :can_access_dashboard?

  def current_store
    @current_store ||= user_signed_in? && current_user.store || current_store_by_request
  end

  def shopping_cart
    @shopping_cart ||= current_user.shopping_cart
  end

  def can_shop?
    @can_shop = current_user.can?(:shop, store: current_store) if @can_shop.nil?
    @can_shop
  end

  def can_see_pricing?
    @can_see_pricing = current_user.has_role?(:see_pricing) if @can_see_pricing.nil?
    @can_see_pricing
  end

  def can_see_stock?
    @can_see_stock = current_user.has_role?(:see_stock) if @can_see_stock.nil?
    @can_see_stock
  end

  def can_manage?
    @can_manage = current_user.has_role?(:manager) if @can_manage.nil?
    @can_manage
  end

  def can_access_dashboard?
    @can_access_dashboard = current_user.has_role?(:dashboard_access) if @can_access_dashboard.nil?
    @can_access_dashboard
  end

  private
    # Pages are loaded by a before_filter, since their links are
    # rendered in the main navigation bar.
    def load_pages
      @pages ||= current_store.pages.top_level.ordered
    end

    # Locale is set by a before_filter. Using params is a manual override
    # not available in the user interface.
    def set_locale
      I18n.locale = params[:locale] || current_store.locale || I18n.default_locale
    end

    # When no user is signed in, or a guest user is created, the current store
    # is looked up by the requested hostname.
    def current_store_by_request
      Store.find_by(host: request.host)
    end

    def create_guest_user
      guest = User.new(
        store: current_store_by_request,
        guest: true,
        name: 'Guest',
        email: "guest_#{Time.now.to_i}#{rand(100)}@leasit.info",
        roles: Role.guest_roles
      )
      guest.save!(validate: false)
      session[:guest_user_id] = guest.id
      guest
    end
end
