// Cabeçalho:
//  Este módulo tem como objetivo delinear a classe Conversa, que por tabela também define que campos o objeto conversa terá no Firestore
//  1.Adicionamos uma booleana para informar se a conversa foi arquivada, e um método para mudar esta booleana no Firestore

import 'package:cloud_firestore/cloud_firestore.dart';
class Conversa {

  String _idRemetente;
  String _idDestinatario;
  String _nome;
  String _mensagem;
  Timestamp _timeStamp; // LEK
  String _caminhoFoto;
  String _tipoMensagem;//texto ou imagem

  bool _arquivada;

  Conversa();

  arquivar() async {
    Firestore db = Firestore.instance;
    await db.collection("conversas")
        .document( this.idRemetente )
        .collection( "ultima_conversa" )
        .document( this.idDestinatario )
        .setData( this.toMap() );
  }

  salvar() async { // isso pode ser feito de um jeito melhor, mas esse é mais simples e elegante
    /*

    + conversas
      + jamilton
          + ultima_conversa
            + jose
              idRe
              idDes
              ...

    */
    Firestore db = Firestore.instance;
    await db.collection("conversas")
            .document( this.idRemetente )
            .collection( "ultima_conversa" )
            .document( this.idDestinatario )
            .setData( this.toMap() );

  }

  Map<String, dynamic> toMap(){

    Map<String, dynamic> map = {
      "idRemetente"     : this.idRemetente,
      "idDestinatario"  : this.idDestinatario,
      "nome"            : this.nome,
      "mensagem"        : this.mensagem,
      "timeStamp"       : this.timeStamp,
      "caminhoFoto"     : this.caminhoFoto,
      "tipoMensagem"    : this.tipoMensagem,
      "arquivada" : this._arquivada, // abv
    };

    return map;

  }


  //get e set do _arquivada
  set arquivada(bool b){
    _arquivada = b;
  }
  bool get arquivada => arquivada;
  //abv

  Timestamp get timeStamp => _timeStamp; //LEK

  set timeStamp(Timestamp value) { //LEK
    _timeStamp = value;
  }

  String get idRemetente => _idRemetente;

  set idRemetente(String value) {
    _idRemetente = value;
  }

  String get nome => _nome;

  set nome(String value) {
    _nome = value;
  }

  String get mensagem => _mensagem;

  String get caminhoFoto => _caminhoFoto;

  set caminhoFoto(String value) {
    _caminhoFoto = value;
  }

  set mensagem(String value) {
    _mensagem = value;
  }

  String get idDestinatario => _idDestinatario;

  set idDestinatario(String value) {
    _idDestinatario = value;
  }

  String get tipoMensagem => _tipoMensagem;

  set tipoMensagem(String value) {
    _tipoMensagem = value;
  }


}