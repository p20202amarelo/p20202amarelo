// Cabeçalho:
//  Este módulo define a página de adicionar pessoas à um grupo. E todas as suas funcionalidades.

import 'package:flutter/material.dart';
import '../model/Conversa.dart';
import '../model/Usuario.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AbaVerIntegrantes extends StatefulWidget {
  String grupoId;

  AbaVerIntegrantes(this.grupoId);

  @override
  _AbaVerIntegrantesState createState() => _AbaVerIntegrantesState();
}

class _AbaVerIntegrantesState extends State<AbaVerIntegrantes> {

  String _idUsuarioLogado;
  String _emailUsuarioLogado;

  Future<List<Usuario>> _recuperarContatos() async {
    Firestore db = Firestore.instance;

    QuerySnapshot iquery = await db.collection("grupos")
        .document(widget.grupoId)
        .collection("integrantes").getDocuments();



    List<Usuario> listaUsuarios = [];
    for (DocumentSnapshot item in iquery.documents) {

      var dados = item.data;
      if( dados["email"] == _emailUsuarioLogado ) continue;

      Usuario usuario = Usuario();
      usuario.idUsuario = item.documentID;
      usuario.email = dados["email"];
      usuario.nome = dados["nome"];
      usuario.urlImagem = dados["urlImagem"];
      usuario.osId = dados["osId"];

      listaUsuarios.add(usuario);
    }

    return listaUsuarios;
  }

  _recuperarDadosUsuario() async {

    FirebaseAuth auth = FirebaseAuth.instance;
    FirebaseUser usuarioLogado = await auth.currentUser();
    _idUsuarioLogado = usuarioLogado.uid;
    _emailUsuarioLogado = usuarioLogado.email;

  }

  _adicionarUsuario(Usuario usuario) async {
    Firestore db = Firestore.instance;

    db.collection("grupos")
        .document(widget.grupoId)
        .collection("integrantes")
        .document(usuario.idUsuario)
        .setData({"nome" : usuario.nome, "osId" : usuario.osId});

    setState(() {

    });
  }

  @override
  void initState() {
    super.initState();
    _recuperarDadosUsuario();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Usuario>>(
      future: _recuperarContatos(),
      builder: (context, snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.none:
          case ConnectionState.waiting:
            return Center(
              child: Column(
                children: <Widget>[
                  Text("Carregando contatos"),
                  CircularProgressIndicator()
                ],
              ),
            );
            break;
          case ConnectionState.active:
          case ConnectionState.done:
            return ListView.builder(
                itemCount: snapshot.data.length,
                itemBuilder: (_, indice) {

                  List<Usuario> listaItens = snapshot.data;
                  Usuario usuario = listaItens[indice];

                  return ListTile(
                    onTap: (){
                      _adicionarUsuario(usuario);

                    },
                    contentPadding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                    leading: CircleAvatar(
                        maxRadius: 30,
                        backgroundColor: Colors.grey,
                        backgroundImage: usuario.urlImagem != null
                            ? NetworkImage(usuario.urlImagem)
                            : null),
                    title: Text(
                      usuario.nome==null?"":usuario.nome,
                      style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  );
                });
            break;
        }
      },
    );
  }
}
