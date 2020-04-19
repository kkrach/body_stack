
import 'dart:ui';
import 'dart:io';
import 'dart:core';

import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:intl/intl.dart';
import 'package:camera/camera.dart';
import 'package:path/path.dart';
import 'package:sensors/sensors.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

// A screen that allows users to take a picture using a given camera.
class TakePictureScreen extends StatefulWidget {
  final String overlayPath;
  final Directory pictureDirectory;
  TakePictureScreen(this.pictureDirectory, this.overlayPath);

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
    //   _subscriptions.clear();
    //   gyroSubscription.cancel();
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
      ResolutionPreset.max,   // currently 1920x1080 :(
      // enable audio
      enableAudio: false,
    );

    // Next, initialize the controller. This returns a Future.
    _initializeControllerFuture = _controller.initialize();
  }

  _previewWidget(BuildContext context) {

    //return CameraPreview(_controller);

    return RotatedBox(
        quarterTurns: MediaQuery.of(context).orientation == Orientation.landscape ? 3 : 0,
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: CameraPreview(_controller),
        )
    );

        return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: CameraPreview(_controller),
    );
  }

  FutureBuilder<void> _createCameraPreview() {

    return FutureBuilder<void>(
      future: _initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (widget.overlayPath.isEmpty) {
            return Center(
              child: Stack(
                  fit: StackFit.loose,
                  alignment: AlignmentDirectional.center,
                  children: <Widget>[
                    _previewWidget(context),
                    Opacity(
                      opacity: 0.4,
                      child: AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: Image(image: AssetImage('assets/lego.png')),
                      ),
                    ),
                  ]
              ),
            );
          }
          else {
            return Center(
              child: Stack(
                  fit: StackFit.loose,
                  alignment: AlignmentDirectional.center,
                  children: <Widget>[
                    _previewWidget(context),
                    Opacity(
                      opacity: 0.4,
                      child: ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          Colors.grey,
                          BlendMode.dst,
                        ),
                        child: Image(image: FileImage(File(widget.overlayPath))),
                      ),
                    ),
                    StreamBuilder<GyroscopeEvent>(
                      stream: gyroscopeEvents,
                      builder: (BuildContext context, AsyncSnapshot<GyroscopeEvent> snapshot) {
                        if (snapshot.hasError)
                          return Text('Error: ${snapshot.error}');

                        switch (snapshot.connectionState) {
                          case ConnectionState.none: return Text('No gyro data available...');
                          case ConnectionState.waiting: return Text('Awaiting gyro data...');
                          case ConnectionState.active: return Text('\$${snapshot.data}');
                          case ConnectionState.done: return Text('\$${snapshot.data} (closed)');
                        }
                        return Text("Gyro error!");  // can't be reached
                      },
                    ),
                  ]
              ),
            );
          }
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

            DateTime now = DateTime.now();
            String formattedDate = DateFormat('yyyy-MM-dd_kk:mm:ss').format(now);
            final filepath = join(
              widget.pictureDirectory.path,
              'bodystack_' + formattedDate + '.png',
            );

            // Attempt to take a picture and log where it's been saved.
            await _controller.takePicture(filepath);

            // If the picture was taken, display it on a new screen.
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => DisplayPictureScreen(images: [filepath], startIndex: 0),
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


class DisplayPictureScreen extends StatefulWidget {
  final List<String> images;
  final int startIndex;

  const DisplayPictureScreen({Key key, this.images, this.startIndex}) : super(key: key);

  @override
  _DisplayPictureScreenState createState() => _DisplayPictureScreenState(this.startIndex);
}


// A widget that displays the picture taken by the user.
class _DisplayPictureScreenState extends State<DisplayPictureScreen> {

  int index;

  _DisplayPictureScreenState(this.index);

  Future<void> _askForSaveToGallery(BuildContext context, String path) async {
    //
    // needs the following lines into AndroidManifest.xml at profile and/or debug
    //
    // <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
    // <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
    //
    if (! await Permission.storage.request().isGranted) {
      return showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Permission Denied'),
            content: Text('Add WriteExternalStorage permisson manually.'),
            actions: <Widget>[
              FlatButton(
                child: Text('Ok'),
                onPressed: () {
                  Navigator.of(context).pop();
                  openAppSettings();
                },
              ),
            ],
          );
        },
      );
    }

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Save to Gallery'),
          content: Text('Do you want to save this image to the Gallery?'),
          actions: <Widget>[
            FlatButton(
              child: Text('No'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            FlatButton(
              child: Text('Yes'),
              onPressed: () async {
                var result = await ImageGallerySaver.saveFile(path);
                print(result);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _askForDelete(BuildContext context, String path) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Image'),
          content: Text('Do you want to delete this image permanently?'),
          actions: <Widget>[
            FlatButton(
              child: Text('No'),
              onPressed: () async {
                Navigator.of(context).pop();
              },
            ),
            FlatButton(
              child: Text('Yes'),
              onPressed: () async {
                File(path).deleteSync();
                Navigator.of(context).pop();  // close dialog
                Navigator.of(context).pop();  // close image viewer
              },
            ),
          ],
        );
      },
    );
  }

  double currentOpacity = 1.0;
  double nextOpacity = 0.0;
  Offset drag_start;
  Offset drag_last;


  void _onDragStart(DragStartDetails details) {
    setState( () {
      drag_start = details.globalPosition;
      currentOpacity = 1.0;
      nextOpacity = 0.0;
    });
  }
  void _onDragUpdate(DragUpdateDetails details) {
    setState( () {
      ;
      drag_last = details.globalPosition;
      double diff = drag_last.dx - drag_start.dx;
      if (diff < 0) {   // swype left -> backwards
        nextOpacity = 0.0;
        currentOpacity = 1.0 - (-diff / drag_start.dx);
      }
      else {   // swipe right -> forward
        currentOpacity = 1.0;
        double distance = window.physicalSize.width/2 - drag_start.dx;
        nextOpacity = diff / distance;
      }
    });
  }
  void _onDragEnd(DragEndDetails details) {
    setState( () {
      currentOpacity = 1.0;
      nextOpacity = 0.0;
      double diff = drag_last.dx - drag_start.dx;
      if (diff < 0) { // swype left -> backwards
        if (index > 0 && diff.abs() > drag_start.dx/2) {
          index = index - 1;
        }
      }
      else {   // swipe right -> forward
        double distance = window.physicalSize.width/2 - drag_start.dx;
        if (index < widget.images.length-1 && diff > distance/2) {
          index = index + 1;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Display the Picture'),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.image),
            onPressed: () async {
              _askForSaveToGallery(context, widget.images[index]);
              },
          ),
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () {
              _askForDelete(context, widget.images[index]);
              },
          ),
        ],
      ),
      body: GestureDetector(
        onHorizontalDragStart: _onDragStart,
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        child: Stack(
          children: <Widget>[
            Image.file(File(widget.images[index == 0 ? index : index-1])),
            Opacity(
              opacity: currentOpacity,
              child: Image.file(File(widget.images[index])),
            ),
            Opacity(
              opacity: nextOpacity,
              child: Image.file(File(widget.images[index == widget.images.length-1 ? index : index+1])),
            ),
          ],
        ),
      ),
    );
  }
}