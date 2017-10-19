#encoding: utf-8

# Other authorizers should subclass this one

class ApplicationAuthorizer < Authority::Authorizer

  # Any class method from Authority::Authorizer that isn't overridden
  # will call its authorizer's default method.
  #
  # @param [Symbol] adjective; example: `:creatable`
  # @param [Object] user - whatever represents the current user in your app
  # @return [Boolean]
  def self.default(adjective, user, opts = {})
    # 'Whitelist' strategy for security: anything not explicitly allowed is
    # considered forbidden.
    false
  end

  # General authorization to perform any shopping related action
  # at the specified store, given in options.
  def self.authorizes_to_shop?(user, opts = {})
    store = opts[:at]
    return false unless store.allow_shopping?
    user.group(store).outgoing_order_types.any?
  end
end
