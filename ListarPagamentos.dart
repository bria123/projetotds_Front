import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:terraforma/LancamentoPage.dart';

class ListarPagamentos extends StatefulWidget {
  final int user_id;
  final String sessionToken;

  const ListarPagamentos({
    super.key,
    required this.user_id,
    required this.sessionToken,
  });

  @override
  State<ListarPagamentos> createState() => _ListarPagamentosState();
}

class _ListarPagamentosState extends State<ListarPagamentos> {
  Future<dynamic> listarPagamentosBanco() async {
    final url =
        "https://tripwiser.com.br/brian/aplicativo/buscarPagamentos.php?id_usuario=${widget.user_id}";
    final resultado = await http.get(Uri.parse(url));

    if (resultado.statusCode == 200) {
      return json.decode(resultado.body);
    } else {
      throw Exception("Erro ao conectar com o servidor");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pagamentos do Usuário"),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LancamentoPage(
                    user_id: widget.user_id,
                    sessionToken: widget.sessionToken,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.add),
          )
        ],
      ),
      body: FutureBuilder(
        future: listarPagamentosBanco(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Erro: ${snapshot.error}"));
          }
          var data = snapshot.data;
          if (data is Map && data.containsKey('status')) {
            return Center(child: Text("Erro: ${data['message']}"));
          }
          if (data is List && data.isNotEmpty) {
            return ListView.builder(
              itemCount: data.length,
              itemBuilder: (context, index) {
                var item = data[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  child: ListTile(
                    title: Text(item["devedor"] ?? "Sem nome"),
                    subtitle: Text(
                        "Valor: ${item["valor"] ?? "0"} | Data: ${item["data_lancamento"] ?? "?"}"),
                    leading: const Icon(Icons.payment),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        final url = Uri.parse(
                            "https://tripwiser.com.br/brian/aplicativo/deletarPagamento.php");
                        final id = item['id_pagamento'].toString();

                        final response = await http.post(url, body: {
                          'id_pagamento': id,
                        });
                        if (response.statusCode == 200) {
                          var resultado = json.decode(response.body);
                          if (resultado['status'] == 'success') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Deletado com sucesso')),
                            );
                            setState(() {});
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Erro ao deletar')),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Erro de comunicação com o servidor')),
                          );
                        }
                      },
                    ),
                  ),
                );
              },
            );
          }
          return const Center(child: Text("Nenhum pagamento encontrado"));
        },
      ),
    );
  }
}
