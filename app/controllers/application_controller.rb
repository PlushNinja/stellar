#encoding: utf-8

class ApplicationController < ActionController::Base

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  #---
  before_action :load_roles
  before_action :set_locale
  before_action :set_pricing_group
  after_filter :prepare_unobtrusive_flash

  #---
  # Authenticate user, but skip authentication if guests are admitted.
  # This method is the first before_action callback in controllers that
  # optionally serve guests, and will fail early if the current store
  # can't be found.
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

  # Preserves search query param in a cookie.
  def saved_search_query(search_model, cookie_key)
    param = "#{search_model}_search"
    if params[param]
      cookies[cookie_key] = {
        value: params[param].to_json,
        expires: 2.weeks.from_now
      }
    end
    params[param].presence || JSON.load(cookies[cookie_key]) || {}
  end

  # The methods below are for convenience and to cache often repeated
  # database queries on current user and her roles.
  helper_method :current_store, :current_pricing, :shopping_cart, :can_shop?, :can_see_pricing?, :can_see_stock?, :can_manage?

  def current_store
    @current_store ||= user_signed_in? && current_user.store || current_store_by_request
  end

  def current_pricing
    @pricing_group
  end

  def shopping_cart
    @shopping_cart ||= current_user.shopping_cart
  end

  def can_shop?
    @can_shop = current_user.can?(:shop, store: current_store) if @can_shop.nil?
    @can_shop
  end

  def can_see_pricing?
    current_user.has_cached_role?(:see_pricing)
  end

  def can_see_stock?
    current_user.has_cached_role?(:see_stock)
  end

  def can_manage?
    current_user.has_cached_role?(:manager)
  end

  private
    # Preload users with their roles to enable Rolify's caching of roles.
    def load_roles
      current_store.users.preload(:roles)
    end

    def set_pages
      @pages = current_store.pages.includes(:sub_pages).navbar.sorted
    end

    # Locale is set by a before_filter. User locale takes precedence over
    # store locale. Using params is a manual override not available
    # in the user interface.
    def set_locale
      I18n.locale = params[:locale] || user_signed_in? && current_user.locale.presence || current_store.locale || I18n.default_locale
    end

    # Pricing group is set by a before_filter. Changing the pricing group
    # is done by StoreController#pricing and its id is retained in a cookie.
    def set_pricing_group
      pricing_group_id = cookies[:pricing_group_id]
      @pricing_group = current_store.pricing_groups.find_by(id: pricing_group_id)
    end

    # When no user is signed in, or a guest user is created, the current store
    # is looked up by the requested hostname, and must exist.
    def current_store_by_request
      Store.find_by!(host: request.host)
    end

    # Create a record for a guest user and schedule its cleanup
    # to happen after two weeks.
    def create_guest_user
      store = current_store_by_request
      guest = store.users.new(store.guest_user_defaults)
      guest.save!(validate: false)
      session[:guest_user_id] = guest.id
      GuestCleanupJob.set(wait: 2.weeks).perform_later(guest)
      guest
    end
end
