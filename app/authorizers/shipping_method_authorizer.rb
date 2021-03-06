class ShippingMethodAuthorizer < ApplicationAuthorizer

  def self.creatable_by?(user, opts)
    user.has_cached_role?(:superuser, opts[:at]) ||
    user.has_cached_role?(:store_admin, opts[:at])
  end

  def self.readable_by?(user, opts)
    user.has_cached_role?(:superuser, opts[:at]) ||
    user.has_cached_role?(:store_admin, opts[:at])
  end

  def self.updatable_by?(user, opts)
    user.has_cached_role?(:superuser, opts[:at]) ||
    user.has_cached_role?(:store_admin, opts[:at])
  end

  def deletable_by?(user, opts)
    return false if resource.shipments.any?
    user.has_cached_role?(:superuser, opts[:at]) ||
    user.has_cached_role?(:store_admin, opts[:at])
  end
end
