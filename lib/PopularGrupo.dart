// Cabeçalho:
//  Este é o modulo responsável por definir a página de popular um grupo. O grupo a ser modificado é recebido pelo invocador da página.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:p20202amarelo/telas/AbaAddGrupo.dart';
import 'dart:io';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class PopularGrupo extends StatefulWidget {
  String grupoId;

  PopularGrupo(this.grupoId);

  @override
  _PopularGrupoState createState() => _PopularGrupoState();
}

class _PopularGrupoState extends State<PopularGrupo> with SingleTickerProviderStateMixin {

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging(); // abv

  TabController _tabController;
  String _emailUsuario= "";
  String _grupoNome = "";

  _recuperarNomeGrupo() async{
    Firestore db = Firestore.instance;

    DocumentSnapshot grupodata = await db.collection("grupos").document(widget.grupoId).get();

    setState(() {
      _grupoNome = grupodata.data["nome"];
    });


  }

  Future _recuperarDadosUsuario() async {

    FirebaseAuth auth = FirebaseAuth.instance;
    FirebaseUser usuarioLogado = await auth.currentUser();

    String nom;
    await Firestore.instance.collection("usuarios").document(usuarioLogado.uid).get()
        .then((value) => nom = value.data["nome"]);
    // abv - linha abaixo caiu em desuso
    //OneSignal.shared.setExternalUserId(usuarioLogado.uid);

    setState(() {
      _emailUsuario = usuarioLogado.email;
    });

  }

  @override
  void initState() {
    super.initState();
    _recuperarDadosUsuario();
    _recuperarNomeGrupo();
    _tabController = TabController(
        length: 1,
        vsync: this
    );

  }

  Future<bool> onBackPress() {
    openDialog();
    return Future.value(false);
  }

  Future<Null> openDialog() async {
    switch (await showDialog(
        context: context,
        builder: (BuildContext context) {
          return SimpleDialog(
            contentPadding:
            EdgeInsets.only(left: 0.0, right: 0.0, top: 0.0, bottom: 0.0),
            children: <Widget>[
              Container(
                color: Colors.deepOrange,
                margin: EdgeInsets.all(0.0),
                padding: EdgeInsets.only(bottom: 10.0, top: 10.0),
                height: 100.0,
                child: Column(
                  children: <Widget>[
                    Container(
                      child: Icon(
                        Icons.exit_to_app,
                        size: 30.0,
                        color: Colors.white,
                      ),
                      margin: EdgeInsets.only(bottom: 10.0),
                    ),
                    Text(
                      'Exit app',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Are you sure to exit app?',
                      style: TextStyle(color: Colors.white70, fontSize: 14.0),
                    ),
                  ],
                ),
              ),
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, 0);
                },
                child: Row(
                  children: <Widget>[
                    Container(
                      child: Icon(
                        Icons.cancel,
                        color: Colors.deepOrange,
                      ),
                      margin: EdgeInsets.only(right: 10.0),
                    ),
                    Text(
                      'CANCEL',
                      style: TextStyle(
                          color: Colors.deepOrange, fontWeight: FontWeight.bold),
                    )
                  ],
                ),
              ),
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, 1);
                },
                child: Row(
                  children: <Widget>[
                    Container(
                      child: Icon(
                        Icons.check_circle,
                        color: Colors.deepOrange,
                      ),
                      margin: EdgeInsets.only(right: 10.0),
                    ),
                    Text(
                      'YES',
                      style: TextStyle(
                          color: Colors.deepOrange, fontWeight: FontWeight.bold),
                    )
                  ],
                ),
              ),
            ],
          );
        })) {
      case 0:
        break;
      case 1:
        exit(0);
        break;
    }
  }

  _deslogarUsuario() async {

    FirebaseAuth auth = FirebaseAuth.instance;
    await auth.signOut();

    Navigator.pushReplacementNamed(context, "/login");

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Adicione integrantes ao grupo"),
        elevation: Platform.isIOS ? 0 : 4,
        bottom: TabBar(
          indicatorWeight: 4,
          labelStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold
          ),
          controller: _tabController,
          indicatorColor: Platform.isIOS ? Colors.grey[400] : Colors.white,
          tabs: <Widget>[
            Tab(text: _grupoNome,),
          ],
        ),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.arrow_forward_outlined),
            onPressed: (){
              Navigator.pop(context);
            },

          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          AbaAddGrupo(widget.grupoId),
        ],
      ),
    );
  }
}
