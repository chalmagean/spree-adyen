class AdyenConfirmationController < Spree::BaseController

  # possible transaction states
  TRANSACTION_STATES = ["ERROR", "RESERVED", "BILLED", "REVERSED", "CREDITED", "SUSPENDED"]

  # Confirmation interface is a GET request
  def show
    notification = ActiveMerchant::Billing::Integrations::Adyen::Notification.new(request.query_string)
    
    order = Order.find_by_number(notification.item_id)

    case notification.event_code
    when "AUTHORISED"
      # check if the retrieved order is the same as the outgoing one
      if verify_currency(order, params["CURRENCY"])

        # create new payment object
        payment_details = MPaySource.create (
          :p_type => params["P_TYPE"],
          :brand => params["BRAND"],
          :mpayid => params["MPAYTID"]
        )

        payment_details.save!

        # TODO log the payment
        order.checkout.payments.create(
          :amount => params["PRICE"],
          :payment_method_id => nil,
          :source => payment_details
        )

        payment = order.checkout.payments.first
        payment.save!

        payment_details.payment = payment
        payment_details.save!

        price = order.total
        confirmed_price = params["PRICE"].to_i/100.0

        order.complete!

        # do the state change
        if price == confirmed_price
          order.pay!
        elsif price < confirmed_price
          order.over_pay!
        elsif price > confirmed_price
          order.under_pay!
        else
          raise "#{price} vs. #{confirmed price}".inspect
        end
      end
    when "RESERVED"
      raise "send the confirmation request out".inspect
    else
      raise "what is going on?".inspect
    end

    render :text => "OK", :status => 200
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
end
