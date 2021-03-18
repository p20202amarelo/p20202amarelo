// Cabeçalho:
//  Este módulo tem como objetivo delinear a classe Grupo, que por tabela também define que campos o objeto grupo terá no Firestore



import 'package:cloud_firestore/cloud_firestore.dart';

import 'Mensagem.dart';
import 'Usuario.dart';
class Grupo {

  String nome;
  List<Usuario> integrantes; // Talvez usar lista no modelo não seja uma boa ideia
  List<Mensagem> mensagens;

  Grupo();

  salvar() async { // TODO : Definir ou deletar o salvar

  }

  Map<String, dynamic> toMap() { // TODO : Definir o toMap
    Map<String, dynamic> map = {

    };

    return map;
  }

// TODO : Criar os getters e setters

}