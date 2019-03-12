require 'test_helper'
require 'test/unit'
require 'mocha/setup'

class VestaTest < Test::Unit::TestCase

  def setup
    @gateway = VestaGateway.new(fixtures(:vesta))
    @credit_card = ActiveMerchant::Billing::CreditCard.new(
      number:             "340001234527890",
      verification_value: "183",
      month:              "01",
      year:               "2019",
      name:               "John Doe"
    )

    @declined_card = ActiveMerchant::Billing::CreditCard.new(
      number:             "4614201234597890",
      verification_value: "205",
      month:              "01",
      year:               "2019",
      name:               "John Doe"
    )

    @amount = 100
    @options = {
      device_fingerprint:  "41l9l92hjco6cuekf0c7dq68v4",
      order_id: "345454tdf54hj8",
      description: 'Blue clip',
      billing_address: {
        address1: "Rio Missisipi #123",
        address2: "Paris",
        city: "Acapulco",
        region: "Guerrero",
        country: "MX",
        zip: "5555",
        name: "Mario Reyes",
        phone: "12345678",
      },
      web_session_id: "101_2",
      risk_information: "<riskinformation/>"
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal nil, response.message
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_request).returns(failed_purchase_response)
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal nil, response.message
    assert response.test?
  end

  def test_successful_refund
    @gateway.expects(:ssl_request).returns(successful_purchase_response)
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert_equal nil, purchase.message
    assert purchase.test?

    @options[:payment_id] = purchase.params["payment_id"]
    @gateway.expects(:ssl_request).returns(successful_refund_response)
    refund = @gateway.refund(@amount, @credit_card, @options)
    assert_success refund
    assert refund.test?
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    <<-PRE_SCRUBBED
      opening connection to vsafesandbox.ecustomersupport.com:443...
      opened
      starting SSL for vsafesandbox.ecustomersupport.com:443...
      SSL established
      <- \"POST /GatewayV4Proxy/Service/ChargeSale HTTP/1.1\\r\\nContent-Type: application/json\\r\\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\r\\nAccept: */*\\r\\nUser-Agent: Ruby\\r\\nConnection: close\\r\\nHost: vsafesandbox.ecustomersupport.com\\r\\nContent-Length: 686\\r\\n\\r\\n\"
      <- \"{\\\"AccountName\\\":\\\"y+kLIDoU0ox77midoQSorA==\\\",\\\"Password\\\":\\\"PocH4jxAVaJwPnL2rgvD/8N7KQiucdZJJwCtHjHxLpIbxRWvUF2RpImWxB49Ht9y\\\",\\\"TransactionID\\\":\\\"345454tdf54hjj\\\",\\\"ChargeAmount\\\":\\\"100\\\",\\\"ChargeSource\\\":\\\"WEB\\\",\\\"StoreCard\\\":\\\"false\\\",\\\"WebSessionID\\\":\\\"41l9l92hjco6cuekf0c7dq68v4\\\",\\\"MerchantRoutingID\\\":\\\"SandboxCredit01\\\",\\\"RiskInformation\\\":\\\"<riskinformation/>\\\",\\\"CardHolderFirstName\\\":\\\"Mario F.\\\",\\\"CardHolderLastName\\\":\\\"Moreno Reyes\\\",\\\"ChargeAccountNumber\\\":\\\"4242424242424242\\\",\\\"ChargeAccountNumberIndicator\\\":\\\"1\\\",\\\"ChargeCVN\\\":\\\"183\\\",\\\"ChargeExpirationMMYY\\\":\\\"0118\\\",\\\"CardHolderAddressLine1\\\":\\\"Rio Missisipi #123\\\",\\\"CardHolderCity\\\":\\\"Guerrero\\\",\\\"CardHolderRegion\\\":\\\"DF\\\",\\\"CardHolderPostalCode\\\":\\\"5555\\\",\\\"CardHolderCountryCode\\\":\\\"MX\\\"}\"
      -> \"HTTP/1.1 200 \\r\\n\"
      -> \"Cache-Control: no-cache, no-store\\r\\n\"
      -> \"Content-Type: application/json;charset=UTF-8\\r\\n\"
      -> \"Content-Length: 190\\r\\n\"
      -> \"Date: Sat, 22 Apr 2017 11:03:55 GMT\\r\\n\"
      -> \"Connection: close\\r\\n\"
      -> \"Set-Cookie: BIGipServer~eDMZ.Partition~v2-vsafesandbox.ecustomersupport.com-8080=rd3o00000000000000000000ffffac1d1428o8080; path=/\\r\\n\"
      -> \"\\r\\n\"
      reading 190 bytes...
      -> \"{\\\"ResponseCode\\\":\\\"0\\\",\\\"PaymentAcquirerName\\\":\\\"Chase Paymentech\\\",\\\"ChargeAccountLast4\\\":\\\"4242\\\",\\\"PaymentID\\\":\\\"47VATH884\\\",\\\"PaymentDeviceTypeCD\\\":\\\"4\\\",\\\"ChargeAccountFirst6\\\":\\\"424242\\\",\\\"PaymentStatus\\\":\\\"1\\\"}\"
      read 190 bytes
      Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
      opening connection to vsafesandbox.ecustomersupport.com:443...
      opened
      starting SSL for vsafesandbox.ecustomersupport.com:443...
      SSL established
      <- \"POST /GatewayV4Proxy/Service/ChargeSale HTTP/1.1\\r\\nContent-Type: application/json\\r\\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\r\\nAccept: */*\\r\\nUser-Agent: Ruby\\r\\nConnection: close\\r\\nHost: vsafesandbox.ecustomersupport.com\\r\\nContent-Length: 686\\r\\n\\r\\n\"
      <- \"{\\\"AccountName\\\":\\\"[FILTERED]\",\\\"Password\\\":\\\"[FILTERED]\",\\\"TransactionID\\\":\\\"345454tdf54hjj\\\",\\\"ChargeAmount\\\":\\\"100\\\",\\\"ChargeSource\\\":\\\"WEB\\\",\\\"StoreCard\\\":\\\"false\\\",\\\"WebSessionID\\\":\\\"41l9l92hjco6cuekf0c7dq68v4\\\",\\\"MerchantRoutingID\\\":\\\"SandboxCredit01\\\",\\\"RiskInformation\\\":\\\"<riskinformation/>\\\",\\\"CardHolderFirstName\\\":\\\"Mario F.\\\",\\\"CardHolderLastName\\\":\\\"Moreno Reyes\\\",\\\"ChargeAccountNumber\\\":\\\"[FILTERED]\",\\\"ChargeAccountNumberIndicator\\\":\\\"1\\\",\\\"ChargeCVN\\\":\\\"[FILTERED]\",\\\"ChargeExpirationMMYY\\\":\\\"0118\\\",\\\"CardHolderAddressLine1\\\":\\\"Rio Missisipi #123\\\",\\\"CardHolderCity\\\":\\\"Guerrero\\\",\\\"CardHolderRegion\\\":\\\"DF\\\",\\\"CardHolderPostalCode\\\":\\\"5555\\\",\\\"CardHolderCountryCode\\\":\\\"MX\\\"}\"
      -> \"HTTP/1.1 200 \\r\\n\"
      -> \"Cache-Control: no-cache, no-store\\r\\n\"
      -> \"Content-Type: application/json;charset=UTF-8\\r\\n\"
      -> \"Content-Length: 190\\r\\n\"
      -> \"Date: Sat, 22 Apr 2017 11:03:55 GMT\\r\\n\"
      -> \"Connection: close\\r\\n\"
      -> \"Set-Cookie: BIGipServer~eDMZ.Partition~v2-vsafesandbox.ecustomersupport.com-8080=rd3o00000000000000000000ffffac1d1428o8080; path=/\\r\\n\"
      -> \"\\r\\n\"
      reading 190 bytes...
      -> \"{\\\"ResponseCode\\\":\\\"0\\\",\\\"PaymentAcquirerName\\\":\\\"Chase Paymentech\\\",\\\"ChargeAccountLast4\\\":\\\"4242\\\",\\\"PaymentID\\\":\\\"47VATH884\\\",\\\"PaymentDeviceTypeCD\\\":\\\"4\\\",\\\"ChargeAccountFirst6\\\":\\\"424242\\\",\\\"PaymentStatus\\\":\\\"1\\\"}\"
      read 190 bytes
      Conn close
    POST_SCRUBBED
  end

  def successful_purchase_response
    <<-RESPONSE
      {"ResponseCode": "0","PaymentAcquirerName": "Chase Paymentech","ChargeAccountLast4": "6576","PaymentID": "47VATH871","PaymentDeviceTypeCD": "98","ChargeAccountFirst6": "554345","PaymentStatus":"10"}
    RESPONSE
  end
  def failed_purchase_response
    <<-RESPONSE
      {"ResponseCode": "0","PaymentAcquirerName": "Chase Paymentech","ChargeAccountLast4": "6576","PaymentID": "47VATH871","PaymentDeviceTypeCD": "98","ChargeAccountFirst6": "554345","PaymentStatus":"1"}
    RESPONSE
  end

  def successful_refund_response
    <<-RESPONSE
      {"ResponseCode": "0","PaymentAcquirerName": "Chase Paymentech","ChargeAccountLast4": "6576","PaymentID": "47VATH871","PaymentDeviceTypeCD": "98","ChargeAccountFirst6": "554345","PaymentStatus":"1"}
    RESPONSE
  end

end
