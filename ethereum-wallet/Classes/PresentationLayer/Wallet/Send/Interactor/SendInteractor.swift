// ethereum-wallet https://github.com/flypaper0/ethereum-wallet
// Copyright (C) 2018 Artur Guseinov
//
// This program is free software: you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the Free
// Software Foundation, either version 3 of the License, or (at your option)
// any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or
// FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
// more details.
//
// You should have received a copy of the GNU General Public License along with
// this program.  If not, see <http://www.gnu.org/licenses/>.


import Foundation


class SendInteractor {
  weak var output: SendInteractorOutput!
  
  var walletDataStoreService: WalletDataStoreServiceProtocol!
  var transactionsDataStoreService: TransactionsDataStoreServiceProtocol!
  var transactionService: TransactionServiceProtocol!
  var gasService: GasServiceProtocol!

}


// MARK: - SendInteractorInput

extension SendInteractor: SendInteractorInput {
  
  func getCheckout(for coin: Coin, amount: Decimal, iso: String, fee: Decimal) {
    do {
      guard let rate = coin.rates.first(where: {$0.to == iso}) else {
        throw SendCheckoutError.noRate
      }
      let feeAmount = Ether(weiValue: fee)
      let fiatFee = feeAmount.amount(in: iso, rate: rate.value)
      let rawLocalAmount = amount.localToEther(rate: rate.value).toWei()
      let ethAmount = Ether(weiValue: rawLocalAmount + fee)
      let fiatAmount = ethAmount.amount(in: iso, rate: rate.value)
      output.didReceiveCheckout(amount: ethAmount.amount, fiatAmount: fiatAmount, fee: feeAmount.amount, fiatFee: fiatFee)
    } catch let error {
      output.didFailed(with: error)
    }
  }
  
  func getWallet() {
    let wallet = walletDataStoreService.getWallet()
    output.didReceiveWallet(wallet)
  }
  
  func sendTransaction(amount: Decimal, to: String, gasLimit: Decimal, gasPrice: Decimal) {
    do {
      let keychain = Keychain()
      let passphrase = try keychain.getPassphrase()
      let info = TransactionInfo(amount: amount, address: to, contractAddress: nil, gasLimit: gasLimit, gasPrice: gasPrice)
      transactionService.sendTransaction(with: info, passphrase: passphrase) { [weak self] result in
        guard let `self` = self else { return }
        switch result {
        case .success(let sendedTransaction):
          var transaction = Transaction.mapFromGethTransaction(sendedTransaction, time: Date().timeIntervalSince1970)
          transaction.isPending = true
          transaction.isIncoming = false
          self.transactionsDataStoreService.save(transaction)
          self.output.didSendTransaction()
        case .failure(let error):
          self.output.didFailedSending(with: error)
        }
      }
    } catch {
      output.didFailedSending(with: error)
    }
  }
  
  func getGasPrice() {
    gasService.getSuggestedGasPrice() { [weak self] result in
      guard let `self` = self else { return }
      switch result {
      case .success(let gasPrice):
        self.output.didReceiveGasPrice(Decimal(gasPrice))
      case .failure(let error):
        self.output.didFailed(with: error)
      }
    }
  }
  
  func getGasLimit() {
    gasService.getSuggestedGasLimit() { [weak self] result in
      guard let `self` = self else { return }
      switch result {
      case .success(let gasLimit):
        self.output.didReceiveGasLimit(Decimal(gasLimit))
      case .failure(let error):
        self.output.didFailed(with: error)
      }
    }
  }

}
