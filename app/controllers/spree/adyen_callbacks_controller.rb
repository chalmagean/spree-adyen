class Spree::AdyenCallbacksController < Spree::BaseController
  protect_from_forgery :except => :create
  before_filter :adyen_auth
  # possible transaction states
  TRANSACTION_STATES = ["ERROR", "RESERVED", "BILLED", "REVERSED", "CREDITED", "SUSPENDED"]

  # Confirmation interface is a GET request
  def create
    notification = Spree::AdyenNotification.log(params)
    # don't do anything if false was returned
    notification.handle! unless !notification
  rescue ActiveRecord::RecordInvalid => e
    logger.error e
    # Validation failed, because of the duplicate check.
    # So ignore this notification, it is already stored and handled.
  ensure
    # Always return that we have accepted the notification
    render :text => '[accepted]'
  end

  private

  def check_operation(operation)
    if operation != "CONFIRMATION"
      raise "unknown operation: #{operation}".inspect
    end
  end

  def check_status(status)
    if !TRANSACTION_STATES.include?(status)
      raise "unknown status: #{status}".inspect
    end
  end

  def find_order(tid)
    if (order = Order.find(tid)).nil?
      raise "could not find order: #{tid}".inspect
    end

    return order
  end

  def verify_currency(order, currency)
    "EUR" == currency
  end

  def adyen_auth
    preferred_user =  Spree::BillingIntegration::AdyenIntegration.current.preferred_notification_user
    preferred_password =  Spree::BillingIntegration::AdyenIntegration.current.preferred_notification_password
    authenticate_with_http_basic do |user, pass|
      user == preferred_user and pass == preferred_password
    end
  end
end
