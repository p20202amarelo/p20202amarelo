// Cabeçalho:
//  Este módulo define a lista de integrantes que podem ser adicionados a um grupo. E todas as suas funcionalidades.
//  1.O grupo a ser modificado é informado pelo invocador da página

import 'package:flutter/material.dart';
import '../model/Usuario.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AbaAddGrupo extends StatefulWidget {
  String grupoId;

  AbaAddGrupo(this.grupoId);

  @override
  _AbaAddGrupoState createState() => _AbaAddGrupoState();
}

class _AbaAddGrupoState extends State<AbaAddGrupo> {

  String _idUsuarioLogado;
  String _emailUsuarioLogado;

  Future<List<Usuario>> _recuperarIntegrantes() async {
    Firestore db = Firestore.instance;

    QuerySnapshot iquery = await db.collection("grupos")
        .document(widget.grupoId)
        .collection("integrantes").getDocuments();

    List<String> listaIntegrantes = [];
    for (DocumentSnapshot intem in iquery.documents){
      listaIntegrantes.add(intem.documentID);
    }

    QuerySnapshot querySnapshot =
        await db.collection("usuarios")
            .getDocuments();

    List<Usuario> listaUsuarios = [];
    for (DocumentSnapshot item in querySnapshot.documents) {

      var dados = item.data;
      if( dados["email"] == _emailUsuarioLogado ) continue;
      if( listaIntegrantes.contains(item.documentID) )continue;

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

    db.collection("ug_teste") // essa coleção será feita para agilizar a abagrupos
        .document(usuario.idUsuario)
        .setData({});

    var doc = await db.collection("grupos").document(widget.grupoId).get();

    db.collection("ug_teste")
        .document(usuario.idUsuario)
        .collection("grupos")
        .document(widget.grupoId)
        .setData({'nome': doc.data["nome"] });

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
      future: _recuperarIntegrantes(),
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
