// Cabeçalho:
//  Este módulo define a página de cadastro de grupo e todas as suas funcionalidades.
//  1.Quando o botão Continuar, cadastra o grupo. E o usuário logado como único integrante do grupo. Além de levar para PopularGrupo.dart


import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'model/Mensagem.dart';
import 'model/Usuario.dart';

class CriarGrupo extends StatefulWidget {
  @override
  _CriarGrupoState createState() => _CriarGrupoState();
}

class _CriarGrupoState extends State<CriarGrupo> {

  //Controladores
  TextEditingController _controllerNome = TextEditingController(text: "");
  String _mensagemErro = "";

  _validarCampos(){

    //Recupera dados dos campos
    String nome = _controllerNome.text;

    if( nome.isNotEmpty ){
        _cadastrarGrupo();

      }
    else{
      setState(() {
        _mensagemErro = "Preencha o Nome";
      });
    }

  }

  Future<String> _recuperarDadosUsuario() async {

    FirebaseAuth auth = FirebaseAuth.instance;
    FirebaseUser usuarioLogado = await auth.currentUser();
    return usuarioLogado.uid;
  }

  _cadastrarGrupo() async { 

    FirebaseAuth auth = FirebaseAuth.instance;
    FirebaseUser usuarioLogado = await auth.currentUser();

    Firestore db = Firestore.instance;

    DocumentSnapshot item = await db.collection("usuarios").document(usuarioLogado.uid).get();
    var dados = item.data;

    Usuario usuario = Usuario();
    usuario.idUsuario = item.documentID;
    usuario.email = dados["email"];
    usuario.nome = dados["nome"];
    usuario.urlImagem = dados["urlImagem"];
    usuario.osId = dados["osId"];

    DocumentReference docadd = await db.collection("grupos").add({"nome" : _controllerNome.text});
    String grupoId = docadd.documentID;


    Mensagem mensagem = Mensagem();
    mensagem.idUsuario = "sistema";
    mensagem.mensagem = "grupo criado";
    mensagem.timeStamp = Timestamp.now();
    mensagem.tipo = "texto";
    db.collection("grupos")
        .document(grupoId)
        .collection("mensagens")
        .add(mensagem.toMap()); 


    db.collection("grupos")
        .document(grupoId)
        .collection("integrantes")
        .document(usuario.idUsuario)
        .setData({"nome" : usuario.nome, "osId" : usuario.osId});

    String _idUsuarioLogado = await _recuperarDadosUsuario();

    db.collection("ug_teste")
        .document(_idUsuarioLogado)
        .collection("grupos")
        .document(grupoId)
        .setData({'nome': _controllerNome.text});

    Navigator.pushReplacementNamed(context, '/populargrupo', arguments: grupoId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Criar Grupo"),
      ),
      body: Container(
        decoration: BoxDecoration(color: Color(0xff075E54)),
        padding: EdgeInsets.all(16),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: _controllerNome,
                    autofocus: true,
                    keyboardType: TextInputType.text,
                    style: TextStyle(fontSize: 20),
                    decoration: InputDecoration(
                        contentPadding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                        hintText: "Nome do Grupo",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(32))),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 16, bottom: 10),
                  child: RaisedButton(
                      child: Text(
                        "Continuar",
                        style: TextStyle(color: Colors.white, fontSize: 20),
                      ),
                      color: Colors.green,
                      padding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32)),
                      onPressed: () {
                        _validarCampos();
                      }
                  ),
                ),
                Center(
                  child: Text(
                    _mensagemErro,
                    style: TextStyle(
                        color: Colors.red,
                        fontSize: 20
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
