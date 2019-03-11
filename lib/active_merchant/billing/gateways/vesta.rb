module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class VestaGateway < Gateway

      self.supported_countries = ['MX']
      self.default_currency = 'MXN'
      self.supported_cardtypes = [:visa, :master, :american_express]
      self.money_format = :decimals

      self.homepage_url = 'https://trustvesta.com/'
      self.display_name = 'Vesta Gateway'


      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options={})
        requires!(options, :account_name, :password, :merchant_id, :live_url)
        options[:version] ||= '3.3.1'
        @credentials = options
        super
      end

      def purchase(money, payment, options={})
        post = initialize_post
        add_order(post, money, options)
        add_payment_source(post, payment, options)
        add_address(post, payment, options)
        commit(:post, 'ChargeSale', post)
      end

      def authorize(money, payment, options={})
        post = initialize_post
        add_order(post, money, options)
        add_payment_source(post, payment, options)
        add_address(post, payment, options)
        commit(:post, 'ChargeAuthorize', post)
      end

      def capture(money, payment, options={})
        post = initialize_post
        add_order(post, money, options)
        add_payment_source(post, payment, options)
        add_previous_payment_source(post, money, options)
        commit(:post, 'ChargeConfirm', post)
      end

      def refund(money, payment, options={})
        post = initialize_post
        add_previous_payment_source(post, money, options)
        commit(:post, 'ReversePayment', post)
      end

      def void(authorization, options={})
        commit('void', post)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((\"{\\\"AccountName\\\":\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r((\\\"Password\\\":\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r((\\\"ChargeAccountNumber\\\":\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r((\\\"ChargeCVN\\\":\\?")[^"]*)i, '\1[FILTERED]')
      end

      private

      def add_order(post, money, options)
        post[:TransactionID] = options[:order_id] if options[:order_id]
        post[:ChargeAmount] = amount(money)
        post[:ChargeSource] = "WEB"
        post[:StoreCard] = "false"
        post[:WebSessionID] = options[:web_session_id] if options[:web_session_id]
        post[:Fingerprint] = options[:fingerprint] if options[:fingerprint]
        post[:RiskInformation] = options[:risk_information]
        post[:MerchantRoutingID] = @credentials[:merchant_id]
      end

      def add_address(post, creditcard, options)
        if(address = (options[:billing_address] || options[:address] ))
          post[:CardHolderAddressLine1] = address[:address1] if address[:address1]
          post[:CardHolderCity] = address[:city] if address[:city]
          post[:CardHolderRegion] = address[:region] if address[:region]
          post[:CardHolderPostalCode] = address[:zip] if address[:zip]
          post[:CardHolderCountryCode] = address[:country] if address[:country]
        end
      end

      def add_payment_source(post, payment_source, options)
        name = format_name(payment_source.name)
        post[:CardHolderFirstName] = name.first.slice(0,19)
        post[:CardHolderLastName] = name.last.slice(0,19)
        post[:ChargeAccountNumber] = payment_source.number
        post[:ChargeAccountNumberIndicator] = "1"
        post[:ChargeCVN] = payment_source.verification_value
        post[:ChargeExpirationMMYY] = "#{sprintf("%02d", payment_source.month)}#{"#{payment_source.year}"[-2, 2]}"
      end

      def add_previous_payment_source(post, money, options)
        post[:RefundAmount] = amount(money)
        post[:PaymentID] = options[:payment_id]
        post[:TransactionID] = options[:order_id]
        post[:ChargeAccountNumber] = nil
      end

      def parse(body)
        return {} unless body
        JSON.parse(body)
      end

      def headers
        {
          "Content-Type" => "application/json"
        }
      end

      def commit(method, action, parameters)
        url = @credentials[:live_url]
        raw_response = parse(ssl_request(method, url + action, (parameters ? parameters.to_json : nil),  headers))
        begin
          response = format_response(raw_response)
        rescue ResponseError => e
          response = response_error(e.response.body)
        rescue JSON::ParserError
          response = json_error(raw_response)
        rescue StandardError => e
          response = e.message
        end

          response[:code] = fraud_code_from(response) || error_code_from(response)

          Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?
        )

      end

      def success_from(response)
        valid_status = {"10"=>"complete" , "5"=>"authorized"}
        response[:response_code] == "0" && valid_status.keys.include?(response[:payment_status])
      end

      def message_from(response)
        if response[:response_code] == 0
          response.except(response_code)
        else
          response[:response_text]
        end
      end

      def authorization_from(response)
        if response[:response_code] == 0
         response[:payment_status] == 10
        else
          false
        end
      end

      def post_data(action, parameters = {})
        parameters.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end

      def error_code_from(response)
        error_code = ""
        unless success_from(response)
          case response[:payment_status]
          when "1"
            error_code += "bank_declined"
          when "3"
            error_code += "merchant_declined"
          when "6"
            error_code += "communication_error"
          end
          error_code ||= response[:response_text].to_s
        end
        error_code
      end

      def initialize_post()
        post = {}
        post[:AccountName] = @credentials[:account_name]
        post[:Password] = @credentials[:password]
        post
      end

      def fraud_code_from(response)
        return nil if response[:vesta_decision_code].blank?
        codes = {
                  1701 => "Score exceeds risk system thresholds",
                  1702 => "Insufficient information for risk system to approve",
                  1703 => "Insufficient checking account history",
                  1704 => "Suspended account",
                  1705 => "Payment method type is not accepted",
                  1706 => "Duplicate transaction",
                  1707 => "Other payment(s) still in process",
                  1708 => "SSN and/or address did not pass bureau validation",
                  1709 => "Exceeds check amount limit",
                  1710 => "High risk based upon checking account history (EWS)",
                  1711 => "Declined due to ACH regulations",
                  1712 => "Information provided does not match what is on file at bank"
                }
         codes[response[:vesta_decision_code]]
      end

      def format_name(name)
        arr = name.rpartition(' ')
        if arr[0].blank?
          arr[0] = arr[2]
        elsif arr[2].blank?
          arr[2] = arr[0]
        end
        arr
      end

      def format_response(response)
        key_map = { "ResponseCode" => :response_code,
                    "ChargeAccountLast4" => :charge_account_last4,
                     "PaymentID" => :payment_id,
                     "PaymentAcquirerName" => :payment_acquirer_name,
                     "PaymentDeviceTypeCD" => :payment_device_type_cd,
                     "ChargeAccountFirst6" => :charge_account_first6,
                     "PaymentStatus" => :payment_status,
                     "ReversalAction" => :reversal_action,
                     "ResponseText" => :response_text,
                     "VestaDecisionCode" => :vesta_decision_code,
                     "AuthorizedAmount" => :authorized_amount,
                     "AvailableRefundAmount" => :available_refund_amount
                 }
        response.map{|k, v| [key_map[k], v]}.to_h
      end
    end
  end
end
