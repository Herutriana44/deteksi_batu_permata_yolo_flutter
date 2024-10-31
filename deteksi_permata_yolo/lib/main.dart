import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

late List<CameraDescription> cameras;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aplikasi Deteksi Permata',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToCameraScreen();
  }

  Future<void> _navigateToCameraScreen() async {
    await Future.delayed(const Duration(seconds: 3));
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const CameraScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Image.asset(
          'assets/images/logo.jpg',
          width: 200, // Adjust width and height as needed
          height: 200,
        ),
      ),
    );
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  XFile? _image;
  Map<String, dynamic>? _apiResponse;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _controller = CameraController(
      cameras[0],
      ResolutionPreset.high,
    );
    await _controller?.initialize();
    setState(() {});
  }

  Future<void> _takePhoto() async {
    if (_controller != null && _controller!.value.isInitialized) {
      setState(() {
        _isLoading = true; // Show loading indicator
      });

      final XFile photo = await _controller!.takePicture();
      setState(() {
        _image = photo;
      });

      // Send the image to the API
      await _sendImageToAPI(_image!);

      setState(() {
        _isLoading = false; // Hide loading indicator
      });

      // Navigate to the DisplayPhotoScreen and pass the image path and API response
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DisplayPhotoScreen(
            imagePath: _image!.path,
            apiResponse: _apiResponse,
          ),
        ),
      );
    }
  }

  Future<void> _sendImageToAPI(XFile image) async {
    final bytes = await image.readAsBytes();
    final base64Image = base64Encode(bytes);

    final String apiKey = "MOemleWvywA0V6YGtAst"; // Your API Key
    final String modelEndpoint = "permata-svaah/1"; // Model endpoint
    final String uploadURL =
        "https://detect.roboflow.com/$modelEndpoint?api_key=$apiKey&name=YOUR_IMAGE.jpg";

    try {
      final response = await http.post(
        Uri.parse(uploadURL),
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "Content-Length": base64Image.length.toString(),
          "Content-Language": "en-US",
        },
        body: base64Image,
      );

      if (response.statusCode == 200) {
        _apiResponse = jsonDecode(response.body);
        print('API Response: $_apiResponse');
      } else {
        print('Failed to fetch data from API: ${response.statusCode}');
        _apiResponse = null;
      }
    } catch (e) {
      print('Failed to connect to API: $e');
      _apiResponse = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Take a Photo'),
      ),
      body: Stack(
        children: [
          CameraPreview(_controller!),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton(
                onPressed: _takePhoto,
                child: const Text('Capture Photo'),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}

class DisplayPhotoScreen extends StatelessWidget {
  final String imagePath;
  final Map<String, dynamic>? apiResponse;

  const DisplayPhotoScreen({
    super.key,
    required this.imagePath,
    required this.apiResponse,
  });

  @override
  Widget build(BuildContext context) {
    // Check if width and height are double, and convert if necessary
    final double imageWidth =
        (apiResponse?['image']['width'] as num?)?.toDouble() ?? 0.0;
    final double imageHeight =
        (apiResponse?['image']['height'] as num?)?.toDouble() ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Preview'),
      ),
      body: Stack(
        children: [
          Center(child: Image.file(File(imagePath))),
          if (apiResponse != null &&
              apiResponse!['predictions'] != null &&
              apiResponse!['predictions'].isNotEmpty)
            CustomPaint(
              painter: BoundingBoxPainter(
                apiResponse!['predictions'],
                imageWidth,
                imageHeight,
              ),
              child: Container(),
            ),
        ],
      ),
    );
  }
}

class BoundingBoxPainter extends CustomPainter {
  final List<dynamic> predictions;
  final double imageWidth;
  final double imageHeight;

  BoundingBoxPainter(this.predictions, this.imageWidth, this.imageHeight);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
    );

    for (var prediction in predictions) {
      final double x = (prediction['x'] as num).toDouble() -
          (prediction['width'] as num).toDouble() / 2;
      final double y = (prediction['y'] as num).toDouble() -
          (prediction['height'] as num).toDouble() / 2;
      final double width = (prediction['width'] as num).toDouble();
      final double height = (prediction['height'] as num).toDouble();
      final String label =
          '${prediction['class']} ${(prediction['confidence'] * 100).toStringAsFixed(2)}%';

      final rect = Rect.fromLTWH(
        x * size.width / imageWidth,
        y * size.height / imageHeight,
        width * size.width / imageWidth,
        height * size.height / imageHeight,
      );

      canvas.drawRect(rect, paint);

      textPainter.text = TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.red,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );

      textPainter.layout();
      textPainter.paint(
          canvas, Offset(rect.left, rect.top - textPainter.height));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
