import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/web3_service.dart';
import '../utils/constants.dart';

class MyTicketsScreen extends StatefulWidget {
  @override
  _MyTicketsScreenState createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  List<int> _ticketIds = [];
  Map<int, Map<String, dynamic>?> _ticketInfo = {};
  Map<int, bool> _ticketValidity = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    final web3Service = context.read<Web3Service>();
    setState(() => _isLoading = true);
    try {
      final userAddress = web3Service.userAddress;
      if (userAddress != null) {
        final ids = await web3Service.getUserTickets(userAddress);
        for (var id in ids) {
          final info = await web3Service.getTicketInfo(id);
          final valid = await web3Service.isTicketValid(id);
          _ticketInfo[id] = info;
          _ticketValidity[id] = valid;
        }
        setState(() => _ticketIds = ids);
      }
    } catch (e) {
      // Handle error if needed
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Meus Ingressos NFT'),
        backgroundColor: Colors.deepPurple,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _ticketIds.isEmpty
              ? Center(child: Text('Nenhum ingresso encontrado.'))
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _ticketIds.length,
                  itemBuilder: (context, index) {
                    final id = _ticketIds[index];
                    final info = _ticketInfo[id];
                    final valid = _ticketValidity[id] ?? false;
                    return Card(
                      elevation: 4,
                      margin: EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: Icon(
                          valid ? Icons.check_circle : Icons.error,
                          color: valid ? Colors.green : Colors.red,
                        ),
                        title: Text('Ingresso #$id'),
                        subtitle: info != null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Evento: ${info['eventName'] ?? Constants.eventName}'),
                                  Text('Local: ${info['eventVenue'] ?? Constants.eventVenue}'),
                                  Text(
                                    'Data: ${Constants.getEventDateTimeFormatted()}',
                                  ),
                                ],
                              )
                            : Text('Carregando detalhes...'),
                        trailing: valid
                            ? Text('Válido', style: TextStyle(color: Colors.green))
                            : Text('Inválido', style: TextStyle(color: Colors.red)),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        child: Icon(Icons.refresh),
        onPressed: _loadTickets,
        tooltip: 'Recarregar Ingressos',
      ),
    );
  }
}
