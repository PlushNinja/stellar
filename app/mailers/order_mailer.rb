#encoding: utf-8

class OrderMailer < ApplicationMailer

  include Roadie::Rails::Mailer

  #---
  # Order confirmation for the customer. Carbon copies are sent to users
  # who need to be notified of this order.
  def order_confirmation(order)
    @order = order
    @store = order.store

    headers = {
      from: "noreply@#{@store.primary_host.fqdn}",
      to: "#{@order.customer_name} <#{@order.customer_email}>",
      subject: default_i18n_subject(store: @store),
      cc: @order.notified_users.map(&:to_s)
    }
    roadie_mail(headers)
  end

  # Order receipt sent instead of confirmation in non-b2b stores.
  # Carbon copies as per confirmation, but blind.
  def order_receipt(order)
    @order = order
    @store = order.store

    headers = {
      from: "noreply@#{@store.primary_host.fqdn}",
      to: "#{@order.customer_name} <#{@order.customer_email}>",
      subject: default_i18n_subject(store: @store),
      bcc: @order.notified_users.map(&:to_s)
    }
    roadie_mail(headers)
  end

  # Order notification for the contact person.
  def order_notification(order)
    @order = order
    @store = order.store

    headers = {
      from: "noreply@#{@store.primary_host.fqdn}",
      to: @order.contact_string,
      subject: default_i18n_subject(store: @store),
    }
    roadie_mail(headers)
  end

  # Order notification for a vendor group. Only includes the supplied items.
  def vendor_notification(order, vendor, items)
    @order = order
    @store = order.store
    @order_items = items

    headers = {
      from: "noreply@#{@store.primary_host.fqdn}",
      to: vendor.notified_users.map(&:to_s),
      subject: default_i18n_subject(store: @store)
    }
    roadie_mail(headers)
  end

  # Order cancellation to the customer. Carbon copies as per confirmations.
  def order_cancellation(order)
    @order = order
    @store = order.store

    headers = {
      from: "noreply@#{@store.primary_host.fqdn}",
      to: "#{@order.customer_name} <#{@order.customer_email}>",
      subject: default_i18n_subject(store: @store),
      cc: @order.notified_users.map(&:to_s)
    }
    roadie_mail(headers)
  end

  # Quotation from the user to the specified contact, blind carbon copied
  # to the sender.
  def quotation(order)
    @order = order
    @store = order.store
    @user = order.user

    headers = {
      from: @user.to_s,
      to: "#{@order.contact_person} <#{@order.contact_email}>",
      bcc: @user.to_s,
      subject: default_i18n_subject(store: @store)
    }
    roadie_mail(headers)
  end

  protected
    def roadie_options
      super.merge(url_options: {host: @store.primary_host.fqdn})
    end
end
