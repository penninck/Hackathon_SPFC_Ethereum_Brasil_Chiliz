import 'dart:async';
import 'dart:convert';
import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class Web3Service extends ChangeNotifier {
  String? _userAddress;
  bool _isConnected = false;
  String? _connectionError;
  String? _userBalance;

  String? get userAddress => _userAddress;
  bool get isConnected => _isConnected;
  String? get connectionError => _connectionError;
  String? get userBalance => _userBalance;

  Web3Service() {
    _initializeService();
  }

  Future<void> _initializeService() async {
    print('🚀 Inicializando Web3Service...');
    Constants.clearCache();
    await Constants.refreshBlockchainData();
    await restoreConnection();
    print('✅ Web3Service inicializado');
  }

  Future<bool> connectMetaMask() async {
    if (!kIsWeb) {
      _connectionError = Constants.errorMetaMaskNotInstalled;
      notifyListeners();
      return false;
    }
    try {
      if (!_isMetaMaskInstalled()) {
        _connectionError = Constants.errorMetaMaskNotInstalled;
        notifyListeners();
        return false;
      }
      final accounts = await _requestAccounts();
      if (accounts.isEmpty) throw Exception('Nenhuma conta disponível');
      _userAddress = accounts[0];
      _isConnected = true;
      _connectionError = null;
      await _switchToChilizChain();
      await _updateUserBalance();
      await _saveConnection();
      await Constants.refreshBlockchainData();
      notifyListeners();
      return true;
    } catch (e) {
      _connectionError = e.toString();
      notifyListeners();
      return false;
    }
  }

  bool _isMetaMaskInstalled() =>
      js.context.hasProperty('ethereum') && js.context['ethereum'] != null;

  Future<List<String>> _requestAccounts() async {
    final completer = Completer<List<String>>();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final success = 'acc_success_$id';
    final error = 'acc_error_$id';
    js.context[success] = (String res) =>
        completer.complete(List<String>.from(jsonDecode(res)));
    js.context[error] = (String err) => completer.completeError(Exception(err));
    js.context.callMethod('eval', ['''
      window.ethereum.request({method:'eth_requestAccounts'})
        .then(acc=>window.$success(JSON.stringify(acc)))
        .catch(err=>window.$error(err.message||err.toString()));
    ''']);
    final accounts = await completer.future;
    js.context.deleteProperty(success);
    js.context.deleteProperty(error);
    return accounts;
  }

  Future<void> _switchToChilizChain() async {
    try {
      js.context.callMethod('eval', ['''
        window.ethereum.request({
          method:'wallet_switchEthereumChain',
          params:[{chainId:'${Constants.chainIdHex}'}]
        }).catch(err=>{
          if(err.code===4902){
            return window.ethereum.request({
              method:'wallet_addEthereumChain',
              params:[{
                chainId:'${Constants.chainIdHex}',
                chainName:'${Constants.networkName}',
                rpcUrls:['${Constants.rpcUrl}'],
                nativeCurrency:{name:'Chiliz',symbol:'CHZ',decimals:18},
                blockExplorerUrls:['${Constants.blockExplorerUrl}'],
                iconUrls:['https://s2.coinmarketcap.com/static/img/coins/64x64/4066.png']
              }]
            });
          }
          throw err;
        });
      ''']);
    } catch (_) {}
  }

  Future<void> disconnectWallet() async {
    _userAddress = null;
    _isConnected = false;
    _connectionError = null;
    _userBalance = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('connected_wallet_address');
    notifyListeners();
  }

  /// Compra de ingresso enviando valor hex direto (100000 Gwei)
  Future<String> buyTicketWithValue(String valueHex) async {
    if (!_isConnected) throw Exception(Constants.errorWalletNotConnected);
    final completer = Completer<String>();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final success = 'tx_success_$id';
    final error = 'tx_error_$id';

    js.context[success] = (String tx) => completer.complete(tx);
    js.context[error] = (String err) => completer.completeError(Exception(err));

    js.context.callMethod('eval', ['''
      (async () => {
        try {
          const gasPrice = await window.ethereum.request({ method: 'eth_gasPrice' });
          const txHash = await window.ethereum.request({
            method: 'eth_sendTransaction',
            params: [{
              to: '${Constants.contractAddress}',
              from: '$_userAddress',
              value: '$valueHex',
              data: '${Constants.buyTicketSelector}',
              gas: '0x7A120',
              gasPrice: gasPrice
            }]
          });
          window.$success(txHash);
        } catch (err) {
          window.$error(err.message || err.toString());
        }
      })();
    ''']);

    final txHash = await completer.future.timeout(
      Duration(seconds: 120),
      onTimeout: () => throw Exception('Timeout na transação'),
    );

    js.context.deleteProperty(success);
    js.context.deleteProperty(error);

    Future.delayed(Duration(seconds: 3), () {
      Constants.refreshBlockchainData();
      _updateUserBalance();
      notifyListeners();
    });

    return txHash;
  }

  Future<Map<String, dynamic>> getSaleStats() => Constants.getSaleStats();

  Future<Map<String, dynamic>> getEventInfo() => Constants.getEventInfo();

  Future<void> refreshAllData() async {
    Constants.clearCache();
    await Constants.refreshBlockchainData();
    if (_isConnected) await _updateUserBalance();
    notifyListeners();
  }

  Future<List<int>> getUserTickets(String address) async {
    final stats = await getSaleStats();
    final sold = stats['sold'] as int? ?? 0;
    return List.generate(sold, (i) => i + 1);
  }

  Future<Map<String, dynamic>?> getTicketInfo(int tokenId) async {
    return {
      'tokenId': tokenId,
      'purchaseDate': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'buyer': _userAddress,
      'isUsed': false,
      'isValid': true,
    };
  }

  Future<bool> isTicketValid(int tokenId) async => true;

  Future<String> getBalance() async => _userBalance ?? '0.0';

  Future<void> _updateUserBalance() async {
    final completer = Completer<String>();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final success = 'bal_$id';
    final error = 'bal_err_$id';

    js.context[success] = (String bal) => completer.complete(bal);
    js.context[error] = (_) => completer.complete('0x0');

    js.context.callMethod('eval', ['''
      window.ethereum.request({
        method:'eth_getBalance',
        params:['$_userAddress','latest']
      }).then(b=>window.$success(b)).catch(()=>window.$error());
    ''']);

    final hex = await completer.future;
    js.context.deleteProperty(success);
    js.context.deleteProperty(error);

    final clean = hex.replaceFirst('0x', '');
    _userBalance = clean.isNotEmpty
        ? (BigInt.parse(clean, radix: 16) / BigInt.from(10).pow(18))
            .toDouble()
            .toStringAsFixed(4)
        : '0.0';
    notifyListeners();
  }

  Future<void> _saveConnection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('connected_wallet_address', _userAddress!);
  }

  Future<bool> restoreConnection() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('connected_wallet_address');
    if (saved != null && _isMetaMaskInstalled()) {
      final completer = Completer<bool>();
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final success = 'rst_$id';
      js.context[success] = (String res) {
        final acc = List<String>.from(jsonDecode(res));
        completer.complete(acc.contains(saved));
      };
      js.context.callMethod('eval', ['''
        window.ethereum.request({method:'eth_accounts'})
          .then(acc=>window.$success(JSON.stringify(acc)))
          .catch(()=>window.$success('[]'));
      ''']);
      final ok = await completer.future;
      js.context.deleteProperty(success);
      if (ok) {
        _userAddress = saved;
        _isConnected = true;
        await _updateUserBalance();
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    super.dispose();
  }
}
