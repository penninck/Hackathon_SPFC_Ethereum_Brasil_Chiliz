import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/web3_service.dart';
import '../utils/constants.dart';
import 'my_tickets_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _eventInfo;
  Map<String, dynamic>? _saleStats;
  String? _userBalance;
  bool _isLoadingData = true;
  bool _isRefreshing = false;
  bool _isConnecting = false;
  String? _lastTxHash;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _loadEventData();
    await _loadUserBalance();
  }

  Future<void> _loadEventData() async {
    final web3 = context.read<Web3Service>();
    setState(() => _isLoadingData = true);
    try {
      _eventInfo = await web3.getEventInfo();
      _saleStats = await web3.getSaleStats();
    } catch (_) {}
    setState(() => _isLoadingData = false);
  }

  Future<void> _loadUserBalance() async {
    final web3 = context.read<Web3Service>();
    if (web3.isConnected) {
      try {
        _userBalance = await web3.getBalance();
        setState(() {});
      } catch (_) {}
    }
  }

  Future<void> _refreshData() async {
    final web3 = context.read<Web3Service>();
    setState(() => _isRefreshing = true);
    try {
      await web3.refreshAllData();
      await _loadEventData();
      await _loadUserBalance();
    } catch (_) {}
    setState(() => _isRefreshing = false);
  }

  Future<void> _connectWallet() async {
    final web3 = context.read<Web3Service>();
    setState(() => _isConnecting = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Conectando com MetaMask...'),
          ],
        ),
      ),
    );
    final ok = await web3.connectMetaMask();
    Navigator.of(context).pop();
    setState(() => _isConnecting = false);
    if (ok) {
      await _loadUserBalance();
      await _refreshData();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ ${Constants.successWalletConnected}'),
        backgroundColor: Colors.green,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ ${web3.connectionError ?? 'Erro ao conectar'}'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _disconnectWallet() async {
    await context.read<Web3Service>().disconnectWallet();
    setState(() {
      _userBalance = null;
      _lastTxHash = null;
    });
  }

  Future<void> _buyTicket() async {
    final web3 = context.read<Web3Service>();
    try {
      if (_saleStats?['available'] == 0) throw Exception(Constants.errorTicketsSoldOut);
      if (!(_saleStats?['active'] ?? false)) throw Exception(Constants.errorSaleNotActive);
      final bal = double.tryParse(_userBalance ?? '0') ?? 0;
      if (bal < 0.0001 + 0.002) throw Exception(Constants.errorInsufficientFunds);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Processando compra...'),
            ],
          ),
        ),
      );

      // Envia valor fixo de 100000 Gwei (0x5AF3107A4000 wei)
      final tx = await web3.buyTicketWithValue('0x5AF3107A4000');

      Navigator.of(context).pop();
      setState(() => _lastTxHash = tx);
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('🎉 Compra Realizada!'),
            ],
          ),
          content: Text('TX: ${Constants.formatWalletAddress(tx ?? '')}'),
          actions: [
            ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: Text('OK'))
          ],
        ),
      );
    } on Exception catch (e) {
      Navigator.of(context).pop();
      var msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.contains('User rejected')) msg = 'Transação cancelada pelo usuário';
      if (msg.contains('insufficient')) msg = 'Saldo insuficiente';
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('⚠️ Erro na Transação'),
          content: Text(msg),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('FECHAR'))
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final web3 = context.watch<Web3Service>();
    return Scaffold(
      appBar: AppBar(
        title: Text(Constants.eventName),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: _isRefreshing
                ? CircularProgressIndicator(color: Colors.white)
                : Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshData,
          ),
          if (web3.isConnected)
            IconButton(onPressed: _disconnectWallet, icon: Icon(Icons.logout)),
        ],
      ),
      body: _isLoadingData
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshData,
              child: ListView(padding: EdgeInsets.all(16), children: [
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(children: [
                      Text(Constants.eventName,
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text(Constants.eventVenue),
                      SizedBox(height: 8),
                      Text('Preço Fixo: 100000 Gwei'),
                      SizedBox(height: 8),
                      Text('Contrato: ${Constants.formatWalletAddress(Constants.contractAddress)}'),
                    ]),
                  ),
                ),
                SizedBox(height: 16),
                Text('Estatísticas de Venda (Tempo Real)',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Row(children: [
                  Expanded(
                      child: _StatCard(
                          title: 'Vendidos',
                          value: '${_saleStats?['sold']}',
                          color: Colors.green,
                          icon: Icons.check_circle)),
                  SizedBox(width: 8),
                  Expanded(
                      child: _StatCard(
                          title: 'Disponíveis',
                          value: '${_saleStats?['available']}',
                          color: Colors.blue,
                          icon: Icons.inventory)),
                  SizedBox(width: 8),
                  Expanded(
                      child: _StatCard(
                          title: 'Status',
                          value: _saleStats?['active'] == true ? 'Ativo' : 'Inativo',
                          color: Colors.green,
                          icon: Icons.play_arrow)),
                ]),
                SizedBox(height: 24),
                if (!web3.isConnected)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _connectWallet,
                      icon: _isConnecting
                          ? CircularProgressIndicator(color: Colors.white)
                          : Icon(Icons.account_balance_wallet),
                      label: Text(_isConnecting ? 'Conectando...' : 'Conectar MetaMask'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                    ),
                  ),
                if (web3.isConnected) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _buyTicket,
                      icon: Icon(Icons.shopping_cart),
                      label: Text('Comprar ingresso'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green, foregroundColor: Colors.white),
                    ),
                  ),
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                          context, MaterialPageRoute(builder: (_) => MyTicketsScreen())),
                      icon: Icon(Icons.confirmation_number),
                      label: Text('Meus Ingressos NFT'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange, foregroundColor: Colors.white),
                    ),
                  ),
                ],
                if (_lastTxHash != null) ...[
                  SizedBox(height: 16),
                  Text('Última transação:'),
                  SelectableText(_lastTxHash!),
                ],
              ]),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard(
      {required this.title, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(children: [
          Icon(icon, color: color, size: 32),
          SizedBox(height: 8),
          Text(value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          SizedBox(height: 4),
          Text(title),
        ]),
      ),
    );
  }
}
