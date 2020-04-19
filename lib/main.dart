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
      home: DirectoryList(applicationDirectory: this.applicationDirectory),
    );
  }
}






class DirectoryList extends StatefulWidget {

  final Directory applicationDirectory;

  DirectoryList({Key key, this.applicationDirectory}) : super(key: key);

  @override
  _DirectoryListState createState() => _DirectoryListState();
}

class _DirectoryListState extends State<DirectoryList> {

  List<String> _directories = new List<String>();

  void _readinDirectory() {
    setState(() {
      Directory picPath = Directory(join(widget.applicationDirectory.path, 'pictures'));
      picPath.createSync(recursive: true);
      _directories.clear();

      picPath.listSync().forEach( (FileSystemEntity entity) {
        if (entity.statSync().type == FileSystemEntityType.directory) {
          _directories.add(entity.path);
        }
      });
    });
  }

  void _createAndOpenNewStory() async {
    setState( () {
      TextEditingController _controller = TextEditingController();

      showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return new AlertDialog(
            title: Text("Create new Story"),
            contentPadding: const EdgeInsets.all(16.0),
            content: new Row(
              children: <Widget>[
                new Expanded(
                  child: new TextField(
                    autofocus: true,
                    controller: _controller,
                    decoration: new InputDecoration(
                        labelText: 'Story Name',
                        hintText: 'eg. John Smith'
                    ),
                  ),
                )
              ],
            ),
            actions: <Widget>[
              new FlatButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.pop(context);
                  }),
              new FlatButton(
                  child: const Text('Create'),
                  onPressed: () {
                    Navigator.pop(context);
                    Directory newStoryDir = Directory(join(widget.applicationDirectory.path, "pictures", _controller.text));
                    if (!newStoryDir.existsSync()) {
                      newStoryDir.createSync(recursive: true);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PictureList(pictureDirectory: newStoryDir),
                        ),
                      );
                    }
                  }
               )
            ],
          );
        }
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    _readinDirectory();

    if (_directories.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Story List'),
        ),
        body: Center(
          child: Column(
            children: <Widget>[
              Spacer(),
              Text("No story created yet!"),
              Text(""),
              Text("Press PLUS button to create a first story..."),
              Spacer(),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _createAndOpenNewStory,
          tooltip: 'create new story',
          child: Icon(Icons.add),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Story List'),
      ),
      body: ListView.builder(
        itemCount: _directories.length,
        itemBuilder: (BuildContext context, int index) {
          Directory currentDir = Directory(_directories[index]);
          List<FileSystemEntity> pictures = currentDir.listSync();
          var previewImage = pictures.isEmpty ? AssetImage('assets/lego.png') : FileImage(File(pictures.last.path));
          String filename = path.basename(_directories[index]);
          return ListTile(
            title: Text(filename),
            leading: CircleAvatar(
              backgroundImage: previewImage,
            ),
            onTap: () {
              // If the picture was taken, display it on a new screen.
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PictureList(pictureDirectory: Directory(_directories[index])),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createAndOpenNewStory,
        tooltip: 'take new picture',
        child: Icon(Icons.add),
      ),
    );
  }
}






class PictureList extends StatefulWidget {

  final Directory pictureDirectory;

  PictureList({Key key, this.pictureDirectory}) : super(key: key);

  @override
  _PictureListState createState() => _PictureListState();
}

class _PictureListState extends State<PictureList> {

  List<String> _pictures = new List<String>();

  void _readinDirectory() {
    String directory = widget.pictureDirectory.path;
    setState(() {
      Directory path = Directory(directory);
      if (!path.existsSync()) {
        path.create(recursive: true);
      }
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
          return TakePictureScreen(widget.pictureDirectory, _pictures.isEmpty ? "" : _pictures.last);
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
          title: Text('Picture List'),
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
        title: Text('Picture List'),
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

