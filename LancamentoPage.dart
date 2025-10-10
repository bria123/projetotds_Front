import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:terraforma/ListarPagamentos.dart';
import 'dart:convert';
import 'API/Api.dart';
import 'package:flutter/services.dart';



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

  final dataMask = MaskTextInputFormatter(
    mask: '##/##/####',
    filter: {"#": RegExp(r'[0-9]')},
  );
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

  String converterParaFormatoApi(String dataDigitada) {
    try {
      final partes = dataDigitada.split('/'); // [dd, mm, aaaa]
      if (partes.length != 3) return dataDigitada;
      return '${partes[2]}-${partes[1]}-${partes[0]}'; // aaaa-mm-dd
    } catch (_) {
      return dataDigitada;
    }
  }

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
          "data_lancamento": converterParaFormatoApi(dataLancamentoCtrl.text),
          "data_vencimento": converterParaFormatoApi(dataVencimentoCtrl.text),
          "data_pagamento": converterParaFormatoApi(dataPagamentoCtrl.text),
        },
      );

      print(response);
      print(dataLancamentoCtrl);
      print(dataPagamentoCtrl);
      print(dataVencimentoCtrl);

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        setState(() {
          respostaServidor = jsonResponse["message"];
        });
      } else {
        setState(() {
          print(response);
          print(dataLancamentoCtrl);
          print(dataPagamentoCtrl);
          print(dataVencimentoCtrl);
          respostaServidor = "Erro: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {

        print(dataLancamentoCtrl);
        print(dataPagamentoCtrl);
        print(dataVencimentoCtrl);
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

              buildFormFieldComMascara('Data de Lançamento: ', dataLancamentoCtrl, dataMask),
              buildFormFieldComMascara('Data de Lançamento: ', dataVencimentoCtrl, dataMask),
              buildFormFieldComMascara('Data de Lançamento: ', dataPagamentoCtrl, dataMask),

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
Widget buildFormFieldComMascara(
    String labelText, TextEditingController controller, MaskTextInputFormatter mask) {
  return TextFormField(
    controller: controller,
    inputFormatters: [mask],
    keyboardType: TextInputType.number,
    decoration: InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(
        color: Color.fromRGBO(17, 48, 33, 1),
        fontFamily: 'RobotoMono',
      ),
    ),
    style: TextStyle(color: Color.fromRGBO(17, 48, 33, 1)),
  );
}
