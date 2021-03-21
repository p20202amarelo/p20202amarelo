// Cabeçalho:
//  Este é o modulo responsável por definir a página de seleção de conversa (Seja pela aba contatos ou pela aba conversas) e suas funcionalidades.
//  1.Para implementar as notificações, foram colocados os métodos de inicialização do OneSignal.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:p20202amarelo/telas/AbaAddGrupo.dart';
import 'package:p20202amarelo/telas/AbaArquivadas.dart';
import 'telas/AbaContatos.dart';
import 'telas/AbaConversas.dart';
import 'dart:io';
import 'Login.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class PopularGrupo extends StatefulWidget {
  String grupoNome;

  PopularGrupo(this.grupoNome);

  @override
  _PopularGrupoState createState() => _PopularGrupoState();
}

class _PopularGrupoState extends State<PopularGrupo> with SingleTickerProviderStateMixin {

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging(); // abv

  TabController _tabController;
  String _emailUsuario= "";

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

  Future _verificarUsuarioLogado() async {
    FirebaseAuth auth = FirebaseAuth.instance;

    FirebaseUser usuarioLogado = await auth.currentUser();


    if( usuarioLogado == null ){
      Navigator.pushReplacementNamed(context, "/login");
    }

  }

  @override
  void initState() {
    super.initState();
    _verificarUsuarioLogado();
    _recuperarDadosUsuario();
    _tabController = TabController(
        length: 1,
        vsync: this
    );

    //depois deste comentário sou eu (abv) frankensteinizando o código

    registerNotification();

    // colocando o ONE SIGNAL

    initPlatformState();

  }

  //register notification do primeiro exemplo
  void registerNotification() {
    _firebaseMessaging.requestNotificationPermissions();

    _firebaseMessaging.getToken().then((token){
      print('token: $token');
    });
  }

  //implementação do OneSignal
  Future<void> initPlatformState() async {
    if (!mounted) return;

    //Remove this method to stop OneSignal Debugging
    OneSignal.shared.setLogLevel(OSLogLevel.verbose, OSLogLevel.none);

    OneSignal.shared.init(
        "f0a0fb40-2f40-4ac9-a6ab-80f79025eb43",
        iOSSettings: {
          OSiOSSettings.autoPrompt: false,
          OSiOSSettings.inAppLaunchUrl: false
        }
    );
    OneSignal.shared.setInFocusDisplayType(OSNotificationDisplayType.notification);

    // The promptForPushNotificationsWithUserResponse function will show the iOS push notification prompt. We recommend removing the following code and instead using an In-App Message to prompt for notification permission
    await OneSignal.shared.promptUserForPushNotificationPermission(fallbackToSettings: true);

    void _handleSendNotification() async {
      var status = await OneSignal.shared.getPermissionSubscriptionState();

      var playerId = status.subscriptionStatus.userId;

      var notification = OSCreateNotification(
          playerIds: [playerId],
          content: "this is a test from OneSignal's Flutter SDK",
          heading: "Test Notification",
          buttons: [
            OSActionButton(text: "test1", id: "id1"),
            OSActionButton(text: "test2", id: "id2")
          ]);

      var response = await OneSignal.shared.postNotification(notification);
    }

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

  _escolhaMenuItem(String itemEscolhido){

    switch( itemEscolhido ){
      case "Configurações":
        Navigator.pushNamed(context, "/configuracoes");
        break;
      case "Deslogar":
        _deslogarUsuario();
        break;
      case "Criar Grupo":
        Navigator.pushNamed(context, "/criargrupo");
        break;
    }
    //print("Item escolhido: " + itemEscolhido );

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
        title: Text("Adcione integrantes ao grupo"),
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
            Tab(text: widget.grupoNome,),
          ],
        ),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.arrow_forward_outlined),
            onPressed: (){
              Navigator.pushReplacementNamed(context, "/home");
            },

          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          AbaAddGrupo(widget.grupoNome),
        ],
      ),
    );
  }
}
