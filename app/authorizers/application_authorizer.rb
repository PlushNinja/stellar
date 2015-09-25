#encoding: utf-8

# Other authorizers should subclass this one

class ApplicationAuthorizer < Authority::Authorizer

  # Any class method from Authority::Authorizer that isn't overridden
  # will call its authorizer's default method.
  #
  # @param [Symbol] adjective; example: `:creatable`
  # @param [Object] user - whatever represents the current user in your app
  # @return [Boolean]
  def self.default(adjective, user)
    # 'Whitelist' strategy for security: anything not explicitly allowed is
    # considered forbidden.
    false
  end

  # General authorization to perform any shopping related action.
  # The current store is provided as an option.
  def self.authorizes_to_shop?(user, options = {})
    current_store = options[:store]
    current_store.allow_shopping? && (
      user.is_site_manager?  ||
      user.is_site_monitor?  ||
      user.is_store_manager? ||
      user.is_sales_rep?     ||
      user.is_customer?      ||
      user.is_guest? && current_store.admit_guests?
    )
  end

  # General authorization to access the admin dashboard.
  def self.authorizes_to_has_dashboard?(user, options = {})
    user.is_site_manager?  ||
    user.is_site_monitor?  ||
    user.is_store_manager? ||
    false
  end
end
