import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:terraforma/ListarPagamentos.dart';
import 'dart:convert';
import 'API/Api.dart';

class LancamentoPage extends StatefulWidget {
  final int user_id;
  final String sessionToken;

  const LancamentoPage({super.key, required this.user_id, required this.sessionToken});

  @override
  State<LancamentoPage> createState() => _LancamentoPageState();
}

class _LancamentoPageState extends State<LancamentoPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController idControllerUser_id;
  late TextEditingController idControllerSessionToken;


  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    idControllerUser_id = TextEditingController(text: widget.user_id.toString());
    idControllerSessionToken = TextEditingController(text: widget.sessionToken);
  }

  // Controladores dos inputs
  final TextEditingController idUsuarioCtrl = TextEditingController();
  final TextEditingController devedorCtrl = TextEditingController();
  final TextEditingController pagadorCtrl = TextEditingController();
  final TextEditingController descricaoCtrl = TextEditingController();
  final TextEditingController valorCtrl = TextEditingController();
  final TextEditingController dataLancamentoCtrl = TextEditingController();
  final TextEditingController dataVencimentoCtrl = TextEditingController();
  final TextEditingController dataPagamentoCtrl = TextEditingController();

  bool loading = false;
  String respostaServidor = "";

  Future<void> enviarLancamento() async {
    setState(() {
      loading = true;
      respostaServidor = "";
    });

    String urlApi = Api.url;
    String arquivoJson = "Pagamentos.php";
    final url = urlApi + arquivoJson;

    try {
      final response = await http.post(Uri.parse(url),
        body: {
          "id_usuario": widget.user_id.toString(),
          "devedor": devedorCtrl.text,
          "pagador": pagadorCtrl.text,
          "descricao": descricaoCtrl.text,
          "valor": valorCtrl.text,
          "data_lancamento": dataLancamentoCtrl.text,
          "data_vencimento": dataVencimentoCtrl.text,
          "data_pagamento": dataPagamentoCtrl.text,
        },
      );

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        setState(() {
          respostaServidor = jsonResponse["message"];
        });
      } else {
        setState(() {
          respostaServidor = "Erro: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        respostaServidor = "Erro: $e";
      });
    }

    setState(() {
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cadastrar Lançamento")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: devedorCtrl,
                decoration: const InputDecoration(labelText: "Devedor"),
              ),
              TextFormField(
                controller: pagadorCtrl,
                decoration: const InputDecoration(labelText: "Credor"),
              ),
              TextFormField(
                controller: descricaoCtrl,
                decoration: const InputDecoration(labelText: "Descrição"),
              ),
              TextFormField(
                controller: valorCtrl,
                decoration: const InputDecoration(labelText: "Valor"),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: dataLancamentoCtrl,
                decoration: const InputDecoration(labelText: "Data Lançamento (AAAA-MM-DD)"),
              ),
              TextFormField(
                controller: dataVencimentoCtrl,
                decoration: const InputDecoration(labelText: "Data Vencimento (AAAA-MM-DD)"),
              ),
              TextFormField(
                controller: dataPagamentoCtrl,
                decoration: const InputDecoration(labelText: "Data Pagamento (AAAA-MM-DD)"),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: loading ? null : enviarLancamento,
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Cadastrar"),
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: () {Navigator.push(context, MaterialPageRoute(builder: (c) => ListarPagamentos(user_id: widget.user_id, sessionToken: widget.sessionToken)));  }, child: null,

              ),
              const SizedBox(height: 20),
              Text(
                respostaServidor,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
