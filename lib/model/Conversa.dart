import 'package:cloud_firestore/cloud_firestore.dart';
class Conversa {

  String _idRemetente;
  String _idDestinatario;
  String _nome;
  String _mensagem;
  Timestamp _timeStamp; // LEK
  String _caminhoFoto;
  String _tipoMensagem;//texto ou imagem

  // TODO : colocar booleana de arquivado

  Conversa();

  salvar() async {
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
    };

    return map;

  }


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