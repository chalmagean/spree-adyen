class AdyenNotification < ActiveRecord::Base
  belongs_to :payment
  belongs_to :original_notification, :class_name => "AdyenNotification", :foreign_key => "original_reference", :primary_key => "psp_reference"

  def handle!
    payment = if event_code == 'AUTHORISATION'
      Payment.find_by_response_code(psp_reference)
    else
      original_notification.payment
    end
    update_attribute(:payment_id, payment.to_param)

    if success?
      case event_code
      when 'AUTHORISATION'
        payment.started_processing!
        call_capture
        update_attribute(:processed, true)
      when 'CAPTURE'
        payment.complete!
        update_attribute(:processed, true)
      when 'CANCEL_OR_REFUND', 'RECURRING_CONTRACT'
        raise 'Not implemented yet'
      end
    end
  end

  def call_capture
    val = (value.to_f * 100).truncate
    puts "value =#{val}"
    result = Adyen::SOAP::PaymentService.capture(:currency => currency, :value => val, :original_reference => psp_reference) 

    puts result
  end
end
