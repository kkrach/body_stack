import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import 'TakePictureScreen.dart';

Future<void> main() async {

  // Ensure that plugin services are initialized so that `availableCameras()`
  // can be called before `runApp()`
  WidgetsFlutterBinding.ensureInitialized();

  getApplicationDocumentsDirectory().then( (appDir) {
    runApp(BodyStack(appDir));
  } );
}

class BodyStack extends StatelessWidget {

  final Directory applicationDirectory;

  BodyStack(@required this.applicationDirectory);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BodyStack',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Picture List', applicationDirectory: this.applicationDirectory),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title, this.applicationDirectory}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;
  final Directory applicationDirectory;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  List<String> _pictures = new List<String>();

  void _readinDirectory() async {
    String directory = (await getApplicationDocumentsDirectory()).path;
    setState(() {
      Directory path = Directory(join(directory, 'pictures'));
      path.create(recursive: true);
      _pictures.clear();
      path.listSync().forEach( (FileSystemEntity entity) {
        _pictures.add(entity.path);
      });
    });
  }


  void _takePicture() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return TakePictureScreen(_pictures.isEmpty ? "" : _pictures.last);
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    _readinDirectory();

    if (_pictures.isEmpty) {
      return Scaffold(
          appBar: AppBar(
            title: Text(widget.title),
          ),
          body: Center(
            child: Column(
              children: <Widget>[
                Spacer(),
                Text("No images taken yet!"),
                Text(""),
                Text("Press PLUS button to create a first image..."),
                Spacer(),
              ],
            ),
          ),
        floatingActionButton: FloatingActionButton(
          onPressed: _takePicture,
          tooltip: 'take new picture',
          child: Icon(Icons.add),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: ListView.builder(
        itemCount: _pictures.length,
        itemBuilder: (BuildContext context, int index) {
          File imgFile = File(_pictures[index]);
            String filename = path.basename(_pictures[index]);
            return ListTile(
                title: Text(filename.substring(10, filename.length-4)),
                leading: CircleAvatar(
                  backgroundImage: FileImage(imgFile),
                ),
                onTap: () {
                  // If the picture was taken, display it on a new screen.
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DisplayPictureScreen(images: _pictures, startIndex: index),
                    ),
                  );
                },
              );
          },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _takePicture,
        tooltip: 'take new picture',
        child: Icon(Icons.add),
      ),
    );
  }
}

