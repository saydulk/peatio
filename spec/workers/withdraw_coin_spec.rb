# encoding: UTF-8
# frozen_string_literal: true

describe Workers::AMQP::WithdrawCoin do
  let(:member) { create(:member, :barong) }
  let(:withdrawal) { create(:new_btc_withdraw, :with_deposit_liability) }
  let(:processing_withdrawal) do
    create(:new_btc_withdraw, :with_deposit_liability)
      .tap(&:submit!)
      .tap(&:accept!)
      .tap(&:process!)
  end

  context 'withdrawal does not exist' do
    before { Withdraw.expects(:find_by_id).returns(nil) }

    it 'returns nil' do
      expect(Workers::AMQP::WithdrawCoin.new.process(withdrawal.as_json)).to be(nil)
    end
  end

  context 'withdrawal is not in processing state' do
    it 'returns nil' do
      expect(Workers::AMQP::WithdrawCoin.new.process(withdrawal.as_json)).to be(nil)
    end
  end

  context 'withdrawal with empty rid' do
    before do
      # withdrawal.submit!
      # withdrawal.accept!
      # withdrawal.process!
      #
      # Withdraws::Coin.any_instance
      #                .expects(:rid)
      #                .with(anything)
      #                .twice
      #                .returns('')

    end

    # TODO: Finalize me.
    it 'returns nil and fail withdrawal' do
      # expect(Workers::AMQP::WithdrawCoin.new.process(processing_withdrawal.as_json)).to be(nil)
      # expect(processing_withdrawal.reload.failed?).to be_truthy
    end
  end

  context 'hot wallet does not exist' do
    before do
      Wallet.expects(:active)
            .returns(Wallet.none)
    end

    it 'returns nil and skip withdrawal' do
      expect(Workers::AMQP::WithdrawCoin.new.process(processing_withdrawal.as_json)).to be(nil)
      expect(processing_withdrawal.reload.skipped?).to be_truthy
    end
  end

  context 'WalletService2 raises error' do
    before do
      WalletService.expects(:new)
        .raises(Peatio::Wallet::Registry::NotRegisteredAdapterError)
    end

    it 'returns true and marks withdrawal as failed' do
      expect(Workers::AMQP::WithdrawCoin.new.process(processing_withdrawal.as_json)).to be_truthy
      expect(processing_withdrawal.reload.failed?).to be_truthy
    end
  end

  context 'wallet balance is not sufficient' do
    before do
      WalletService.any_instance
                    .expects(:load_balance!)
                    .returns(withdrawal.amount * 0.9)
    end

    it 'returns nil and skip withdrawal' do
      expect(Workers::AMQP::WithdrawCoin.new.process(processing_withdrawal.as_json)).to be(true)
      expect(processing_withdrawal.reload.skipped?).to be_truthy
    end
  end

  context 'wallet balance is sufficient but build_withdrawal! raises error' do
    before do
      WalletService.any_instance
                    .expects(:load_balance!)
                    .returns(withdrawal.amount)

      WalletService.any_instance
                    .expects(:build_withdrawal!)
                    .with(instance_of(Withdraws::Coin))
                    .raises(Peatio::Blockchain::ClientError)
    end

    it 'returns true and marks withdrawal as failed' do
      expect(Workers::AMQP::WithdrawCoin.new.process(processing_withdrawal.as_json)).to be_truthy
      expect(processing_withdrawal.reload.failed?).to be_truthy
    end
  end

  context 'wallet balance is sufficient but build_withdrawal! returns transaction' do
    before do
      WalletService.any_instance
                    .expects(:load_balance!)
                    .returns(withdrawal.amount)

      transaction = Peatio::Transaction.new(amount: withdrawal.amount,
                                            to_address: withdrawal.rid,
                                            hash: 'hash-1')
      WalletService.any_instance
                    .expects(:build_withdrawal!)
                    .with(instance_of(Withdraws::Coin))
                    .returns(transaction)
    end

    it 'returns true and dispatch withdrawal' do
      expect(Workers::AMQP::WithdrawCoin.new.process(processing_withdrawal.as_json)).to be_truthy
      expect(processing_withdrawal.reload.confirming?).to be_truthy
      expect(processing_withdrawal.txid).to eq('hash-1')
    end
  end

  context 'marks withdraw as undefined on Faraday::TimeoutError error' do
    before do
      WalletService.any_instance
                   .expects(:load_balance!)
                   .returns(withdrawal.amount)

      Bitcoin::Client.any_instance
                   .expects(:connection)
                   .raises(Faraday::TimeoutError.new)
    end

    subject { Workers::AMQP::WithdrawCoin.new.process(processing_withdrawal.as_json) }

    it 'sets undefined state after processing withdrawal' do
      expect(subject).to be_truthy
      expect(processing_withdrawal.reload.undefined?).to be_truthy
    end

    it 'doesn\'t retry on time-out error' do
      expect(Workers::AMQP::WithdrawCoin.new.process(processing_withdrawal.as_json)).to be_truthy
      expect(processing_withdrawal.reload.undefined?).to be_truthy
    end
  end
end
