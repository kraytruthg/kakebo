class Api::V1::QuickEntriesController < Api::V1::BaseController
  def create
    parsed = QuickEntryParser.parse(extract_text)
    return render_error("無法解析，請用「描述 金額」格式") unless parsed

    resolved = QuickEntryResolver.resolve(parsed, Current.household)
    account = resolved[:account] || default_account
    return render_error("找不到帳戶，請先在 App 建立帳戶") unless account

    if resolved[:category].present?
      create_transaction(account, resolved)
    else
      create_pending_confirmation(parsed, resolved)
    end
  end

  private

  def extract_text
    params[:text].presence ||
      params.except(:controller, :action, :format).values.detect { |v| v.is_a?(String) && v.present? }.to_s
  end

  def default_account
    Current.household.default_account ||
      Current.household.accounts.budget.active.first ||
      Current.household.accounts.active.first
  end

  def create_transaction(account, resolved)
    transaction = account.transactions.build(
      category: resolved[:category],
      amount: -resolved[:amount].abs,
      date: resolved[:date],
      memo: resolved[:memo]
    )
    if transaction.save
      account.recalculate_balance!
      render_success(message: "已記帳：#{resolved[:category].name} $#{resolved[:amount].abs}")
    else
      render_error("建立失敗：#{transaction.errors.full_messages.join(', ')}")
    end
  end

  def create_pending_confirmation(parsed, resolved)
    token = SecureRandom.hex(20)
    Rails.cache.write(
      "quick_entry_confirm:#{token}",
      {
        user_id: Current.user.id,
        amount: parsed[:amount],
        memo: resolved[:memo],
        payer: parsed[:payer],
        description: parsed[:description]
      },
      expires_in: 30.minutes
    )
    confirm_url = quick_entry_confirm_url(token: token)
    render json: { status: "needs_confirmation", confirm_url: confirm_url }
  end
end
