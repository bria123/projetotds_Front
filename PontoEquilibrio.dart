import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:http/http.dart' as http;

class PontoEquilibrio extends StatefulWidget {

  final int user_id;
  final String sessionToken;

  const PontoEquilibrio(
        {
          super.key,
          required this.user_id,
          required this.sessionToken
        }
      );

  @override
  State<PontoEquilibrio> createState() => _PontoEquilibrioState();
}

class _PontoEquilibrioState extends State<PontoEquilibrio> {
  late TextEditingController idControllerUser_id;
  late TextEditingController idControllerSessionToken;
  final TextEditingController custosFixosController = TextEditingController();
  final TextEditingController custosVariaveisController = TextEditingController();
  final TextEditingController precoVendaController = TextEditingController();
  final TextEditingController dataController = TextEditingController();
  final TextEditingController filtroDataController = TextEditingController();

  bool _isLoading = false;
  List<dynamic> _registros = [];
  List<dynamic> _registrosFiltrados = [];
  int _paginaAtual = 0;
  final int _itensPorPagina = 10;

  // Controllers para o pró-labore
  final TextEditingController lucroLiquidoController = TextEditingController();
  final TextEditingController porcentagemRetiradaController = TextEditingController();
  double _resultadoProLabore = 0;
  bool _mostrarResultadoProLabore = false;

  final maskFormatter = MaskTextInputFormatter(
    mask: 'R\$ ####,##',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
    initialText: '',
  );

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'), // Adiciona o locale em português
    );
    if (picked != null) {
      setState(() {
        // Formata a data no formato dd/MM/yyyy para exibição
        dataController.text = "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }

  // calcular ponto de equilibrio
  Future<void> _calcularPontoEquilibrio() async {
    final String custosFixos = custosFixosController.text.trim();
    final String custosVariaveis = custosVariaveisController.text.trim();
    final String precoVenda = precoVendaController.text.trim();
    final String data = dataController.text.trim();

    if (custosFixos.isEmpty || custosVariaveis.isEmpty || precoVenda.isEmpty || data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor, preencha todos os campos.")),
      );
      return;
    }

    // cálculo do ponto de equilíbrio
    double resultado = 0;
    try {
      // Remove R$, pontos e troca vírgula por ponto
      final double cf = double.parse(custosFixos.replaceAll('R\$ ', '').replaceAll('.', '').replaceAll(',', '.'));
      final double cv = double.parse(custosVariaveis.replaceAll('R\$ ', '').replaceAll('.', '').replaceAll(',', '.'));
      final double pv = double.parse(precoVenda.replaceAll('R\$ ', '').replaceAll('.', '').replaceAll(',', '.'));

      if (pv <= cv) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("O preço de venda deve ser maior que os custos variáveis.")),
        );
        return;
      }

      resultado = cf / (pv - cv);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Valores inválidos para cálculo.")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Limpa os valores para enviar à API
      final String cfLimpo = custosFixos.replaceAll('R\$ ', '').replaceAll('.', '').replaceAll(',', '.');
      final String cvLimpo = custosVariaveis.replaceAll('R\$ ', '').replaceAll('.', '').replaceAll(',', '.');
      final String pvLimpo = precoVenda.replaceAll('R\$ ', '').replaceAll('.', '').replaceAll(',', '.');

      // Converte data de dd/MM/yyyy para yyyy-MM-dd (formato do banco de dados)
      final List<String> dataParts = data.split('/');
      final String dataFormatada = '${dataParts[2]}-${dataParts[1]}-${dataParts[0]}';

      // Debug: imprime os valores que serão enviados
      print('Enviando para API:');
      print('id_usuario: ${widget.user_id}');
      print('data: $dataFormatada');
      print('custos_fixos: $cfLimpo');
      print('custos_variaveis: $cvLimpo');
      print('preco_venda: $pvLimpo');
      print('resultado: ${resultado.toStringAsFixed(2)}');

      final uri = Uri.parse("https://tripwiser.com.br/brian/aplicativo/Ponto_Equilibrio.php");
      final response = await http.post(uri, body: {
        "id_usuario": widget.user_id.toString(),
        "data": dataFormatada,
        "custos_fixos": cfLimpo,
        "custos_variaveis": cvLimpo,
        "preco_venda": pvLimpo,
        "resultado": resultado.toStringAsFixed(2), // Envia o resultado calculado como string
      }).timeout(const Duration(seconds: 15));

      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          // Atualiza a lista de registros
          setState(() {
            _registros = responseData['data'] ?? [];
            _aplicarFiltro(); // Aplica filtro após atualizar
          });

          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text("Sucesso"),
                content: Text("Ponto de equilíbrio calculado: ${resultado.toStringAsFixed(0)} unidades."),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Limpa os campos
                      custosFixosController.clear();
                      custosVariaveisController.clear();
                      precoVendaController.clear();
                      dataController.clear();
                    },
                    child: const Text("OK"),
                  ),
                ],
              );
            },
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(responseData['message'] ?? "Erro ao salvar dados.")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro na comunicação: Status ${response.statusCode}")),
        );
      }
    } catch (e) {
      print('Erro capturado: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _carregarRegistros() async {
    try {
      final uri = Uri.parse("https://tripwiser.com.br/brian/aplicativo/Ponto_Equilibrio.php");
      final response = await http.post(uri, body: {
        "id_usuario": widget.user_id.toString(),
        "listar": "true", // Flag para indicar que é apenas listagem
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          setState(() {
            _registros = responseData['data'] ?? [];
            _aplicarFiltro();
          });
        }
      }
    } catch (e) {
      print('Erro ao carregar registros: $e');
    }
  }

  void _aplicarFiltro() {
    if (filtroDataController.text.isEmpty) {
      _registrosFiltrados = List.from(_registros);
    } else {
      final filtro = filtroDataController.text;
      // Converte o filtro de dd/MM/yyyy para DateTime
      final partsFiltro = filtro.split('/');
      if (partsFiltro.length == 3) {
        final dataFiltro = DateTime(
          int.parse(partsFiltro[2]), // ano
          int.parse(partsFiltro[1]), // mês
          int.parse(partsFiltro[0]), // dia
        );

        _registrosFiltrados = _registros.where((registro) {
          final data = registro['data'] ?? '';
          if (data.contains('-')) {
            final parts = data.split('-');
            if (parts.length == 3) {
              // Converte data do registro de yyyy-MM-dd para DateTime
              final dataRegistro = DateTime(
                int.parse(parts[0]), // ano
                int.parse(parts[1]), // mês
                int.parse(parts[2]), // dia
              );
              // Retorna true se a data do registro for maior ou igual à data do filtro
              return dataRegistro.isAfter(dataFiltro) || dataRegistro.isAtSameMomentAs(dataFiltro);
            }
          }
          return false;
        }).toList();
      } else {
        _registrosFiltrados = List.from(_registros);
      }
    }
    _paginaAtual = 0;
  }

  List<dynamic> _getRegistrosPaginados() {
    final inicio = _paginaAtual * _itensPorPagina;
    final fim = inicio + _itensPorPagina;
    if (inicio >= _registrosFiltrados.length) return [];
    return _registrosFiltrados.sublist(
      inicio,
      fim > _registrosFiltrados.length ? _registrosFiltrados.length : fim,
    );
  }

  int get _totalPaginas => (_registrosFiltrados.length / _itensPorPagina).ceil();

  Future<void> _selectFiltroData(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) {
      setState(() {
        filtroDataController.text = "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
        _aplicarFiltro();
      });
    }
  }

  void _calcularProLabore() {
    final String lucroLiquido = lucroLiquidoController.text.trim();
    final String porcentagem = porcentagemRetiradaController.text.trim();

    if (lucroLiquido.isEmpty || porcentagem.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor, preencha todos os campos.")),
      );
      return;
    }

    try {
      // Remove R$, pontos e troca vírgula por ponto
      final double lucro = double.parse(lucroLiquido.replaceAll('R\$ ', '').replaceAll('.', '').replaceAll(',', '.'));
      final double percent = double.parse(porcentagem.replaceAll('%', '').replaceAll(',', '.'));

      if (percent < 0 || percent > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("A porcentagem deve estar entre 0 e 100.")),
        );
        return;
      }

      setState(() {
        _resultadoProLabore = lucro * (percent / 100);
        _mostrarResultadoProLabore = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Valores inválidos para cálculo.")),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    idControllerUser_id =
        TextEditingController(text: widget.user_id.toString());
    idControllerSessionToken =
        TextEditingController(text: widget.sessionToken.toString());

    // Preenche o campo de data com a data atual
    final now = DateTime.now();
    dataController.text = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";

    _carregarRegistros(); // Carrega os registros ao abrir a tela
  }

  @override
  void dispose() {
    idControllerUser_id.dispose();
    idControllerSessionToken.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Cálculos Financeiros",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color.fromRGBO(0, 88, 144, 1), Color.fromRGBO(0, 120, 190, 1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
      ),
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card do Ponto de Equilíbrio
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, Colors.blue.shade50.withOpacity(0.3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Card(
                elevation: 0,
                color: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Título com ícone
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue[600]!, Colors.blue[800]!],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.analytics_outlined,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Ponto de Equilíbrio",
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[900],
                                  ),
                                ),
                                Text(
                                  "Calcule quantas unidades precisa vender",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      // Campo de data
                      TextField(
                        controller: dataController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: "Data",
                          labelStyle: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.w600),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.blue[700]!, width: 2.5),
                          ),
                          suffixIcon: Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.calendar_today, color: Colors.blue[700], size: 20),
                          ),
                        ),
                        onTap: () => _selectDate(context),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: custosFixosController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [maskFormatter],
                        decoration: InputDecoration(
                          labelText: "Custos Fixos Mensais",
                          labelStyle: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.w600),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.blue[700]!, width: 2.5),
                          ),
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.account_balance_wallet_outlined, color: Colors.blue[700], size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: custosVariaveisController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [maskFormatter],
                        decoration: InputDecoration(
                          labelText: "Custos Variáveis por Unidade",
                          labelStyle: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.w600),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.blue[700]!, width: 2.5),
                          ),
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.trending_up, color: Colors.blue[700], size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: precoVendaController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [maskFormatter],
                        decoration: InputDecoration(
                          labelText: "Preço de Venda por Unidade",
                          labelStyle: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.w600),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.blue[700]!, width: 2.5),
                          ),
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.monetization_on_outlined, color: Colors.blue[700], size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue[600]!, Colors.blue[800]!],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _calcularPontoEquilibrio,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    strokeWidth: 3,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.calculate_outlined, size: 22),
                                    SizedBox(width: 10),
                                    Text(
                                      "Calcular Ponto de Equilíbrio",
                                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            // Card do Histórico
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, Colors.lightBlue.shade50.withOpacity(0.3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.lightBlue.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Card(
                elevation: 0,
                color: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.lightBlue[600]!, Colors.lightBlue[800]!],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.lightBlue.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.history,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Histórico de Cálculos",
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.lightBlue[900],
                                  ),
                                ),
                                Text(
                                  "Consulte seus registros anteriores",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: filtroDataController,
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: "Filtrar por Data",
                                labelStyle: TextStyle(color: Colors.lightBlue[700], fontWeight: FontWeight.w600),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: Colors.lightBlue[700]!, width: 2.5),
                                ),
                                suffixIcon: Container(
                                  margin: const EdgeInsets.all(8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.lightBlue[50],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.calendar_today, color: Colors.lightBlue[700], size: 20),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                              onTap: () => _selectFiltroData(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.red[400]!, Colors.red[600]!],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white, size: 24),
                              onPressed: () {
                                setState(() {
                                  filtroDataController.clear();
                                  _aplicarFiltro();
                                });
                              },
                              tooltip: "Limpar filtro",
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _registrosFiltrados.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(50),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.inbox_outlined,
                                      size: 72,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    "Nenhum registro encontrado",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Comece realizando seu primeiro cálculo",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(color: Colors.grey[200]!, width: 1.5),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.08),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: DataTable(
                                        headingRowColor: MaterialStateProperty.all(Colors.lightBlue[50]),
                                        headingRowHeight: 56,
                                        dataRowHeight: 64,
                                        columns: [
                                          DataColumn(
                                            label: Text(
                                              'Data',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.lightBlue[900]),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Custos Fixos',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.lightBlue[900]),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Custos Var.',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.lightBlue[900]),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Preço Venda',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.lightBlue[900]),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Resultado',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.lightBlue[900]),
                                            ),
                                          ),
                                        ],
                                        rows: _getRegistrosPaginados().map((registro) {
                                          String dataFormatada = registro['data'] ?? '';
                                          if (dataFormatada.contains('-')) {
                                            final parts = dataFormatada.split('-');
                                            if (parts.length == 3) {
                                              dataFormatada = '${parts[2]}/${parts[1]}/${parts[0]}';
                                            }
                                          }

                                          String formatarMoeda(dynamic valor) {
                                            try {
                                              final num = double.parse(valor.toString());
                                              return 'R\$ ${num.toStringAsFixed(2).replaceAll('.', ',')}';
                                            } catch (e) {
                                              return valor.toString();
                                            }
                                          }

                                          String formatarResultado(dynamic valor) {
                                            try {
                                              final num = double.parse(valor.toString());
                                              return '${num.toStringAsFixed(0)} un.';
                                            } catch (e) {
                                              return '${valor} un.';
                                            }
                                          }

                                          return DataRow(cells: [
                                            DataCell(Text(dataFormatada, style: const TextStyle(fontSize: 14))),
                                            DataCell(Text(formatarMoeda(registro['custos_fixos']), style: const TextStyle(fontSize: 14))),
                                            DataCell(Text(formatarMoeda(registro['custos_variaveis']), style: const TextStyle(fontSize: 14))),
                                            DataCell(Text(formatarMoeda(registro['preco_venda']), style: const TextStyle(fontSize: 14))),
                                            DataCell(
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [Colors.green[400]!, Colors.green[600]!],
                                                  ),
                                                  borderRadius: BorderRadius.circular(10),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.green.withOpacity(0.3),
                                                      blurRadius: 6,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: Text(
                                                  formatarResultado(registro['resultado']),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ]);
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.grey[100]!, Colors.grey[200]!],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.info_outline, size: 18, color: Colors.grey[700]),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Página ${_paginaAtual + 1} de ${_totalPaginas > 0 ? _totalPaginas : 1} • ${_registrosFiltrados.length} registros',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: _paginaAtual > 0
                                            ? LinearGradient(
                                                colors: [Colors.lightBlue[600]!, Colors.lightBlue[800]!],
                                              )
                                            : LinearGradient(
                                                colors: [Colors.grey[300]!, Colors.grey[400]!],
                                              ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: _paginaAtual > 0
                                            ? [
                                                BoxShadow(
                                                  color: Colors.lightBlue.withOpacity(0.3),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ]
                                            : [],
                                      ),
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.arrow_back_ios, size: 18),
                                        label: const Text("Anterior", style: TextStyle(fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          foregroundColor: Colors.white,
                                          shadowColor: Colors.transparent,
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        onPressed: _paginaAtual > 0
                                            ? () {
                                                setState(() {
                                                  _paginaAtual--;
                                                });
                                              }
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: _paginaAtual < _totalPaginas - 1
                                            ? LinearGradient(
                                                colors: [Colors.lightBlue[600]!, Colors.lightBlue[800]!],
                                              )
                                            : LinearGradient(
                                                colors: [Colors.grey[300]!, Colors.grey[400]!],
                                              ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: _paginaAtual < _totalPaginas - 1
                                            ? [
                                                BoxShadow(
                                                  color: Colors.lightBlue.withOpacity(0.3),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ]
                                            : [],
                                      ),
                                      child: ElevatedButton.icon(
                                        label: const Text("Próxima", style: TextStyle(fontWeight: FontWeight.bold)),
                                        icon: const Icon(Icons.arrow_forward_ios, size: 18),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          foregroundColor: Colors.white,
                                          shadowColor: Colors.transparent,
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        onPressed: _paginaAtual < _totalPaginas - 1
                                            ? () {
                                                setState(() {
                                                  _paginaAtual++;
                                                });
                                              }
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            // Card do Pró-Labore
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, Colors.indigo.shade50.withOpacity(0.3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.indigo.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Card(
                elevation: 0,
                color: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.indigo[600]!, Colors.indigo[800]!],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.indigo.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.account_balance,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Cálculo de Pró-Labore",
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo[900],
                                  ),
                                ),
                                Text(
                                  "Calcule sua retirada mensal",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: lucroLiquidoController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [maskFormatter],
                        decoration: InputDecoration(
                          labelText: "Lucro Líquido Mensal",
                          labelStyle: TextStyle(color: Colors.indigo[700], fontWeight: FontWeight.w600),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.indigo[700]!, width: 2.5),
                          ),
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.indigo[50],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.attach_money, color: Colors.indigo[700], size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: porcentagemRetiradaController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: "Porcentagem de Retirada",
                          labelStyle: TextStyle(color: Colors.indigo[700], fontWeight: FontWeight.w600),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.indigo[700]!, width: 2.5),
                          ),
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.indigo[50],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.percent, color: Colors.indigo[700], size: 20),
                          ),
                          suffixText: '%',
                          suffixStyle: TextStyle(color: Colors.indigo[700], fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.indigo[600]!, Colors.indigo[800]!],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.indigo.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _calcularProLabore,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.calculate_outlined, size: 22),
                              SizedBox(width: 10),
                              Text(
                                "Calcular Pró-Labore",
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (_mostrarResultadoProLabore)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.indigo[500]!, Colors.indigo[700]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.indigo.withOpacity(0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.indigo[700],
                                  size: 52,
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                "Resultado do Cálculo",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  "R\$ ${_resultadoProLabore.toStringAsFixed(2).replaceAll('.', ',')}",
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo[700],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  "Este é o valor que você pode retirar mensalmente como pró-labore.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
