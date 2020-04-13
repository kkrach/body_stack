import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;


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

  List<FileSystemEntity> _files = new List<FileSystemEntity>();

  void _readinDirectory() async {
    String directory = (await getApplicationDocumentsDirectory()).path;
    setState(() {
      Directory path = Directory(join(directory, 'pictures'));
      path.create(recursive: true);
      _files = path.listSync();  //use your folder name insted of resume.
    });
  }


  void _takePicture() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return TakePictureScreen();
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    _readinDirectory();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: ListView.builder(
        itemCount: _files.length,
        itemBuilder: (BuildContext context, int index) {
          File imgFile = File(_files[index].path);
            String filename = path.basename(_files[index].path);
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
                      builder: (context) => DisplayPictureScreen(imagePath: _files[index].path),
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
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}


// A screen that allows users to take a picture using a given camera.
class TakePictureScreen extends StatefulWidget {
  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  CameraController _controller;
  Future<void> _initializeControllerFuture;
  Future<List<CameraDescription>> _availableCameras;

  @override
  void initState() {
    super.initState();

    this._availableCameras = availableCameras();
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    _controller.dispose();
    super.dispose();
  }

  void _initializeCameraPreview(CameraDescription camera) {
    // To display the current output from the Camera,
    // create a CameraController.
    _controller = CameraController(
      // Get a specific camera from the list of available cameras.
      camera,
      // Define the resolution to use.
      ResolutionPreset.medium,
    );

    // Next, initialize the controller. This returns a Future.
    _initializeControllerFuture = _controller.initialize();
  }

  FutureBuilder<void> _createCameraPreview() {
    return FutureBuilder<void>(
      future: _initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          // If the Future is complete, display the preview.
          return Stack(
              fit: StackFit.loose,
              alignment: AlignmentDirectional.center,
              children: <Widget>[
                CameraPreview(_controller),
                Opacity(
                    opacity: 0.6,
                    child: Image(image: AssetImage('assets/lego.png'))
                ),
              ]
            );
        } else {
          // Otherwise, display a loading indicator.
          return Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Take a picture')),
      // Wait until the controller is initialized before displaying the
      // camera preview. Use a FutureBuilder to display a loading spinner
      // until the controller has finished initializing.
      body: FutureBuilder<List<CameraDescription>>(
            future: _availableCameras,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                List<CameraDescription> cameras = snapshot.data;
                // If the Future is complete, display the preview.
                _initializeCameraPreview(cameras.first);
                return _createCameraPreview();
              } else {
                // Otherwise, display a loading indicator.
                return Center(child: CircularProgressIndicator());
              }
            },
          ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.camera_alt),
        // Provide an onPressed callback.
        onPressed: () async {
          // Take the Picture in a try / catch block. If anything goes wrong,
          // catch the error.
          try {
            // Ensure that the camera is initialized.
            await _initializeControllerFuture;

            // Construct the path where the image should be saved using the
            // pattern package.
            final path = join(
              // Store the picture in the temp directory.
              // Find the temp directory using the `path_provider` plugin.
              (await getApplicationDocumentsDirectory()).path,
              'pictures',
            );
            Directory(path).create(recursive: true);

            DateTime now = DateTime.now();
            String formattedDate = DateFormat('yyyy-MM-dd_kk:mm:ss').format(now);
            final filepath = join(
              path,
              'bodystack_' + formattedDate + '.png',
            );

            // Attempt to take a picture and log where it's been saved.
            await _controller.takePicture(filepath);

            // If the picture was taken, display it on a new screen.
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => DisplayPictureScreen(imagePath: filepath),
              ),
            );
          } catch (e) {
            // If an error occurs, log the error to the console.
            print(e);
          }
        },
      ),
    );
  }
}

// A widget that displays the picture taken by the user.
class DisplayPictureScreen extends StatelessWidget {
  final String imagePath;

  const DisplayPictureScreen({Key key, this.imagePath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Display the Picture')),
      // The image is stored as a file on the device. Use the `Image.file`
      // constructor with the given path to display the image.
      body: Image.file(File(imagePath)),
    );
  }
}