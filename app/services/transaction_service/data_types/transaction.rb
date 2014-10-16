module TransactionService::DataTypes::Transaction

  PaypalCompletePreauthorizationFields = EntityUtils.define_builder(
    [:payment_gateway, const_value: :paypal],
    [:pending_reason, :string, :optional])

  # Common response format:

  TransactionResponse = EntityUtils.define_builder(
    [:transaction, :hash, :mandatory],
    [:gateway_fields, :hash, :optional])

  module_function

  def create_paypal_complete_preauthorization_fields(fields); PaypalCompletePreauthorizationFields.call(fields) end

  def create_transaction_response(transaction, gateway_fields = {})
    TransactionResponse.call({
        transaction: transaction,
        gateway_fields: gateway_fields
      })
  end
end

