// Cabeçalho:
//  Este módulo é responsavel por definir a página de configurações de conta. E todas as suas funcionalidades.
//  1.Para implementar a opção de mudar e-mail e senha foram criados os TextControllers para e-mail e senha sao acionados tanto firebase_auth quanto firestore para atualizar os campos.
//  1.1.Quando o botão "Salvar" é apertado, os controladores de e-mail e senha são checados, e se não estiverem vazios, fazem o update de e-mail e senha no firebase

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:developer';

class Configuracoes extends StatefulWidget {
  @override
  _ConfiguracoesState createState() => _ConfiguracoesState();
}

class _ConfiguracoesState extends State<Configuracoes> {

  TextEditingController _controllerNome = TextEditingController();
  TextEditingController _controllerEmail = TextEditingController();
  TextEditingController _controllerSenha = TextEditingController();
  final emailCheck = RegExp(r"(^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$)");
  File _imagem;
  String _idUsuarioLogado;
  String _emailUsuarioLogado;
  bool _subindoImagem = false;
  String _urlImagemRecuperada;
  static ImagePicker _imagePicker = null;

  _ConfiguracoesState(){
    if (_imagePicker == null)
      _imagePicker = ImagePicker();
  }

  Future _recuperarImagem(String origemImagem) async {

    PickedFile imagemSelecionada;  // LEK File imagemSelecionada;
    switch( origemImagem ){
      case "camera" :
        imagemSelecionada = await _imagePicker.getImage(source: ImageSource.camera);// await ImagePicker.pickImage(source: ImageSource.camera);
        break;
      case "galeria" :
        imagemSelecionada = await _imagePicker.getImage(source: ImageSource.gallery);// await ImagePicker.pickImage(source: ImageSource.gallery);
        break;
    }

    setState(() {
      _imagem = File(imagemSelecionada.path);
      if( _imagem != null ){
        _subindoImagem = true;
        _uploadImagem();
      }
    });

  }

  Future _uploadImagem() async {

    FirebaseStorage storage = FirebaseStorage.instance;
    StorageReference pastaRaiz = storage.ref();
    StorageReference arquivo = pastaRaiz
      .child("perfil")
      .child(_idUsuarioLogado + ".jpg");

    //Upload da imagem
    StorageUploadTask task = arquivo.putFile(_imagem);

    //Controlar progresso do upload
    task.events.listen((StorageTaskEvent storageEvent){

      if( storageEvent.type == StorageTaskEventType.progress ){
        setState(() {
          _subindoImagem = true;
        });
      }else if( storageEvent.type == StorageTaskEventType.success ){
        setState(() {
          _subindoImagem = false;
        });
      }

    });

    //Recuperar url da imagem
    task.onComplete.then((StorageTaskSnapshot snapshot){
      _recuperarUrlImagem(snapshot);
    });

  }

  Future _recuperarUrlImagem(StorageTaskSnapshot snapshot) async {

    String url = await snapshot.ref.getDownloadURL();
    _atualizarUrlImagemFirestore( url );

    setState(() {
      _urlImagemRecuperada = url;
    });

  }

  _atualizarNomeFirestore(){

    String nome = _controllerNome.text;
    Firestore db = Firestore.instance;

    Map<String, dynamic> dadosAtualizar = {
      "nome" : nome
    };

    db.collection("usuarios")
        .document(_idUsuarioLogado)
        .updateData( dadosAtualizar );

  }

  _atualizarEmailFirestore() {

    String email = _controllerEmail.text;
    Firestore db = Firestore.instance;
    if (email == ''){
      log("null");
    }else {
      if(emailCheck.hasMatch(email)){
        Map<String, dynamic> dadosAtualizar = {
          "email" : email
        };

        db.collection("usuarios")
            .document(_idUsuarioLogado)
            .updateData( dadosAtualizar );

        _atualizarEmailAuth(email).then((value) => log("$value"));
        _onLoading();
      }else {
        log("not email");
      }
    }
  }

  void _onLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          child: Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: new Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: new CircularProgressIndicator(),
                ),
                new Text("Loading"),
              ],
            ),
          ),
        );
      },
    );
    new Future.delayed(new Duration(seconds: 3), () {
      Navigator.pop(context); //pop dialog

    });
  }


  Future _atualizarEmailAuth(String newEmail) async {
    var message;
    FirebaseUser firebaseUser = await FirebaseAuth.instance.currentUser();
    log("_atualizarEmailAuth function call args $newEmail");
    log("$firebaseUser");
    firebaseUser
        .updateEmail(newEmail)
        .then(
          (value) => message = "#### email update",
    )
        .catchError((onError) => message = 'error');

    
    return message;
  }

  Future _atualizarSenha() async {
    // usando a mesma técnica que o método acima
    String newPassword = _controllerSenha.text;
    if(newPassword == ''){
      print("no password");
      return;
    }
    else{
      FirebaseUser firebaseUser = await FirebaseAuth.instance.currentUser();
      firebaseUser.updatePassword(newPassword);
    }
  }

  _atualizarUrlImagemFirestore(String url){

    Firestore db = Firestore.instance;

    Map<String, dynamic> dadosAtualizar = {
      "urlImagem" : url
    };
    
    db.collection("usuarios")
    .document(_idUsuarioLogado)
    .updateData( dadosAtualizar );

  }

  _recuperarDadosUsuario() async {

    FirebaseAuth auth = FirebaseAuth.instance;
    FirebaseUser usuarioLogado = await auth.currentUser();
    _idUsuarioLogado = usuarioLogado.uid;
    _emailUsuarioLogado = usuarioLogado.email;
    _controllerEmail.text = _emailUsuarioLogado;
    Firestore db = Firestore.instance;
    DocumentSnapshot snapshot = await db.collection("usuarios")
      .document( _idUsuarioLogado )
      .get();

    Map<String, dynamic> dados = snapshot.data;
    _controllerNome.text = dados["nome"];

    if( dados["urlImagem"] != null ){
      setState(() {
        _urlImagemRecuperada = dados["urlImagem"];
      });
    }

  }

  @override
  void initState() {
    super.initState();
    _recuperarDadosUsuario();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Configurações"),),
      body: Container(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                Container(
                  padding: EdgeInsets.all(16),
                  child: _subindoImagem
                      ? CircularProgressIndicator()
                      : Container(),
                ),
                CircleAvatar(
                  radius: 100,
                  backgroundColor: Colors.grey,
                  backgroundImage:
                  _urlImagemRecuperada != null
                      ? NetworkImage(_urlImagemRecuperada)
                      : null
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    FlatButton(
                      child: Text("Câmera"),
                      onPressed: (){
                        _recuperarImagem("camera");
                      },
                    ),
                    FlatButton(
                      child: Text("Galeria"),
                      onPressed: (){
                        _recuperarImagem("galeria");
                      },
                    )
                  ],
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: _controllerNome,
                    autofocus: true,
                    keyboardType: TextInputType.text,
                    style: TextStyle(fontSize: 20),
                    /*onChanged: (texto){
                      _atualizarNomeFirestore(texto);
                    },*/
                    decoration: InputDecoration(
                        contentPadding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                        hintText: "Nome",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(32))),
                  ),
                ),

                
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: _controllerEmail,
                    autofocus: true,
                    keyboardType: TextInputType.text,
                    style: TextStyle(fontSize: 20),
                    /*onChanged: (texto){
                      _atualizarNomeFirestore(texto);
                    },*/
                    decoration: InputDecoration(
                        contentPadding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                        hintText: "$_emailUsuarioLogado",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(32))),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: _controllerSenha,
                    obscureText: true,
                    autofocus: true,
                    keyboardType: TextInputType.text,
                    style: TextStyle(fontSize: 20),
                    decoration: InputDecoration(
                        contentPadding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                        hintText: "senha",
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
                        "Salvar",
                        style: TextStyle(color: Colors.white, fontSize: 20),
                      ),
                      color: Colors.green,
                      padding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32)),
                      onPressed: () {
                        _atualizarNomeFirestore();
                        _atualizarEmailFirestore();
                        // atualizar email
                        _atualizarSenha();
                      }
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
