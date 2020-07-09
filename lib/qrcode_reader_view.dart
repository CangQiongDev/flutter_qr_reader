import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
//import 'package:flutter_admin_app/res/colors.dart';
import 'package:image_picker/image_picker.dart';

import 'flutter_qr_reader.dart';

/// 使用前需已经获取相关权限
/// Relevant privileges must be obtained before use
class QrcodeReaderView extends StatefulWidget {
  final Widget headerWidget;
  final Future Function(String) onScan;
  final double scanBoxRatio;
  final Color boxLineColor;
  final Widget helpWidget;
  final Color borderColor;
  final double borderWidth;
  final double borderHeight;
  QrcodeReaderView({
    Key key,
    @required this.onScan,
    this.headerWidget,
    this.boxLineColor = Colors.cyanAccent,
    this.helpWidget,
    this.scanBoxRatio = 0.65,
    this.borderColor = Colors.green,
    this.borderWidth = 4.0,
    this.borderHeight = 20.0,
  }) : super(key: key);

  @override
  QrcodeReaderViewState createState() => new QrcodeReaderViewState();
}

/// 扫码后的后续操作
/// ```dart
/// GlobalKey<QrcodeReaderViewState> qrViewKey = GlobalKey();
/// qrViewKey.currentState.startScan();
/// ```
class QrcodeReaderViewState extends State<QrcodeReaderView>
    with TickerProviderStateMixin {
  QrReaderViewController _controller;
  AnimationController _animationController;
  bool openFlashlight;
  Timer _timer;
  ui.Image _image;
  bool _isImageloaded = false;
  @override
  void initState() {
    super.initState();
    openFlashlight = false;
    _init();
  }

  ///延迟开始动画
  void _init() async {
    await Future.delayed(Duration(microseconds: 200));
    _initAnimation();
    final ByteData data = await rootBundle.load('assets/scan_blue.png');
    _image = await loadImage(new Uint8List.view(data.buffer));
  }

  Future<ui.Image> loadImage(List<int> img) async {
    final Completer<ui.Image> completer = new Completer();
    ui.decodeImageFromList(img, (ui.Image img) {
      setState(() {
        _isImageloaded = true;
      });
      return completer.complete(img);
    });
    return completer.future;
  }

  void _initAnimation() {
    setState(() {
      _animationController = AnimationController(
          vsync: this, duration: Duration(milliseconds: 3000));
    });
    _animationController.forward();
    _animationController
      ..addListener(_upState)
      ..addStatusListener((state) {
        if (state == AnimationStatus.completed) {
          _timer = Timer(Duration(milliseconds: 10), () {
            _animationController?.reverse(from: 0.0);
          });
        } else if (state == AnimationStatus.dismissed) {
          _timer = Timer(Duration(milliseconds: 100), () {
            _animationController?.forward(from: 0.0);
          });
        }
      });
//    _animationController.forward(from: 0.0);
  }

  void _clearAnimation() {
    _timer?.cancel();
    if (_animationController != null) {
      _animationController?.dispose();
      _animationController = null;
    }
  }

  void _upState() {
    setState(() {});
  }

  void _onCreateController(QrReaderViewController controller) async {
    _controller = controller;
    _controller.startCamera(_onQrBack);
  }

  bool isScan = false;
  Future _onQrBack(data, _) async {
    if (isScan == true) return;
    isScan = true;
    stopScan();
    await widget.onScan(data);
  }

  void startScan() {
    isScan = false;
    _controller.startCamera(_onQrBack);
    _initAnimation();
  }

  void stopScan() {
    _clearAnimation();
    _controller.stopCamera();
  }

  Future<bool> setFlashlight() async {
    openFlashlight = await _controller.setFlashlight();
    setState(() {});
    return openFlashlight;
  }

  Future scanImage() async {
    stopScan();
    var image = await ImagePicker.pickImage(source: ImageSource.gallery);
    if (image == null) {
      startScan();
      return;
    }
    final rest = await FlutterQrReader.imgScan(image);
    await widget.onScan(rest);
    startScan();
  }

  @override
  Widget build(BuildContext context) {
    final flashOpen = Image.asset(
      "assets/tool_flashlight_open.png",
      package: "flutter_qr_reader",
      width: 35,
      height: 35,
      color: Colors.white,
    );
    final flashClose = Image.asset(
      "assets/tool_flashlight_close.png",
      package: "flutter_qr_reader",
      width: 35,
      height: 35,
      color: Colors.white,
    );
    if (_isImageloaded == true) {
      return Material(
        color: Colors.black,
        child: LayoutBuilder(builder: (context, constraints) {
          final qrScanSize = constraints.maxWidth * widget.scanBoxRatio;
          final mediaQuery = MediaQuery.of(context);
          if (constraints.maxHeight < qrScanSize * 1.5) {
            print("建议高度与扫码区域高度比大于1.5");
          }
          return Stack(
            children: <Widget>[
              SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: QrReaderView(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  callback: _onCreateController,
                  scanBoxRatio: widget.scanBoxRatio,
                ),
              ),
              Positioned(
                left: (constraints.maxWidth - qrScanSize) / 2,
                top: (constraints.maxHeight - qrScanSize) / 2,
                child: CustomPaint(
                  painter: QrScanBoxPainter(
                    maxWidth: constraints.maxWidth,
                    maxHeight: constraints.maxHeight,
                    borderColor: widget.borderColor,
                    borderWidth: widget.borderWidth,
                    borderHeight: widget.borderHeight,
                    boxLineColor: widget.boxLineColor,
                    animationValue: _animationController?.value ?? 0,
                    isForward:
                        _animationController?.status == AnimationStatus.forward,
                    image: _image,
                  ),
                  child: SizedBox(
                    width: qrScanSize,
                    height: qrScanSize,
                  ),
                ),
              ),
              widget.headerWidget ?? widget.headerWidget,
              Positioned(
                top: (constraints.maxHeight + qrScanSize) / 2 + 30,
                width: constraints.maxWidth,
                child: Align(
                  alignment: Alignment.center,
                  child: DefaultTextStyle(
                    style: TextStyle(color: Color(0xFFcccccc)),
                    child: widget.helpWidget ?? Text("请将二维码置于方框中"),
                  ),
                ),
              ),
              Positioned(
                top: (constraints.maxHeight + qrScanSize) / 2 - 50,
                width: constraints.maxWidth,
                child: Align(
                  alignment: Alignment.center,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: setFlashlight,
                    child: openFlashlight ? flashOpen : flashClose,
                  ),
                ),
              ),

//            Positioned(
//              width: constraints.maxWidth,
//              bottom: constraints.maxHeight == mediaQuery.size.height
//                      ? 12 + mediaQuery.padding.top
//                      : 12,
//              child: Row(
//                crossAxisAlignment: CrossAxisAlignment.center,
//                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                children: <Widget>[
//                  GestureDetector(
//                    behavior: HitTestBehavior.translucent,
//                    onTap: scanImage,
//                    child: Container(
//                      width: 45,
//                      height: 45,
//                      alignment: Alignment.center,
//                      child: Image.asset(
//                        "assets/tool_img.png",
//                        package: "flutter_qr_reader",
//                        width: 25,
//                        height: 25,
//                        color: Colors.white54,
//                      ),
//                    ),
//                  ),
//                  Container(
//                    width: 80,
//                    height: 80,
//                    decoration: BoxDecoration(
//                      borderRadius: BorderRadius.all(Radius.circular(40)),
//                      border: Border.all(color: Colors.white30, width: 12),
//                    ),
//                    alignment: Alignment.center,
//                    child: Image.asset(
//                      "assets/tool_qrcode.png",
//                      package: "flutter_qr_reader",
//                      width: 35,
//                      height: 35,
//                      color: Colors.white54,
//                    ),
//                  ),
//                  SizedBox(width: 45, height: 45),
//                ],
//              ),
//            )
            ],
          );
        }),
      );
    } else {
      return Container();
    }
  }

  @override
  void dispose() {
    _clearAnimation();
    super.dispose();
  }
}

class QrScanBoxPainter extends CustomPainter {
  final double animationValue;
  final bool isForward;
  final Color boxLineColor;
  final Color borderColor;
  final double borderWidth;
  final double borderHeight;
  final double maxWidth;
  final double maxHeight;
  ui.Image image;
  QrScanBoxPainter({
    @required this.animationValue,
    @required this.isForward,
    this.boxLineColor,
    this.borderColor,
    this.borderWidth,
    this.borderHeight,
    @required this.maxWidth,
    @required this.maxHeight,
    this.image,
  })  : assert(animationValue != null),
        assert(isForward != null);

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = Color.fromRGBO(0, 0, 0, 80)
      ..style = PaintingStyle.fill;
    var rect = Rect.fromLTWH(-((maxWidth - size.width) / 2),
        -((maxHeight - size.height) / 2), maxWidth, maxHeight + 100);
    final boxPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOut;
    final cutOutRect = Rect.fromLTWH(
      -borderWidth / 2,
      -borderWidth / 2,
      size.width + borderWidth,
      size.height + borderWidth,
    );
    canvas.saveLayer(
      rect,
      backgroundPaint,
    );
    canvas
      ..drawRect(
        rect,
        backgroundPaint,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          cutOutRect,
          Radius.circular(0.0),
        ),
        boxPaint,
      )
      ..restore();
    final borderRadius = BorderRadius.all(Radius.circular(0)).toRRect(
      Rect.fromLTWH(-borderWidth / 2, -borderWidth / 2,
          size.width + borderWidth, size.height + borderWidth),
    );
    canvas.drawRRect(
      borderRadius,
      Paint()
        ..color = Colors.white54
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6,
    );
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    final path = new Path();
    // leftTop
    path.moveTo(0, borderHeight);
    path.lineTo(0, 0);
    path.quadraticBezierTo(0, 0, 0, 0);
    path.lineTo(borderHeight, 0);
    // rightTop
    path.moveTo(size.width - borderHeight, 0);
    path.lineTo(size.width - 0, 0);
    path.quadraticBezierTo(size.width, 0, size.width, 0);
    path.lineTo(size.width, borderHeight);
    // rightBottom
    path.moveTo(size.width, size.height - borderHeight);
    path.lineTo(size.width, size.height - 0);
    path.quadraticBezierTo(
        size.width, size.height, size.width - 0, size.height);
    path.lineTo(size.width - borderHeight, size.height);
    // leftBottom
    path.moveTo(borderHeight, size.height);
    path.lineTo(0, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - 0);
    path.lineTo(0, size.height - borderHeight);

    canvas.drawPath(path, borderPaint);

    canvas.clipRRect(
        BorderRadius.all(Radius.circular(0)).toRRect(Offset.zero & size));
//    Future<ByteData> data = image.toByteData();
    final lineSize = size.height;
    final leftPress = (size.height + 20.0) * animationValue - 16.0;
    final Size imageSize =
        Size(image.width?.toDouble(), image.height?.toDouble());
    FittedSizes sizes = applyBoxFit(BoxFit.contain, imageSize, size);
    final Rect inputSubRect =
        Alignment.topCenter.inscribe(sizes.source, Offset.zero & imageSize);
    final Rect outputSubRect = Alignment.topCenter
        .inscribe(sizes.destination, Offset(0.0, leftPress) & size);
    canvas.drawImageRect(image, inputSubRect, outputSubRect, Paint());
//        (size.height + lineSize) * animationValue - lineSize + borderWidth / 2;
//    canvas.save();
//    var scale = size.width / image.width;
//    canvas.scale(scale);
//    canvas.drawImage(
//        image,
//        Offset(
//          0.0,
//          leftPress,
//        ),
//        Paint());
//    canvas.restore();
    // 绘制横向网格
//    final linePaint = Paint();
//    final lineSize = size.height * 0.45;
//    final leftPress =
//        (size.height + lineSize) * animationValue - lineSize + borderWidth / 2;
//    linePaint.style = PaintingStyle.stroke;
//    linePaint.shader = LinearGradient(
//      colors: [Colors.transparent, boxLineColor],
//      begin: isForward ? Alignment.topCenter : Alignment(0.0, 2.0),
//      end: isForward ? Alignment(0.0, 0.5) : Alignment.topCenter,
//    ).createShader(Rect.fromLTWH(0, leftPress, size.width, lineSize));
//    for (int i = 0; i < size.height / 5; i++) {
//      canvas.drawLine(
//        Offset(
//          i * 5.0,
//          leftPress,
//        ),
//        Offset(i * 5.0, leftPress + lineSize),
//        linePaint,
//      );
//    }
//    for (int i = 0; i < lineSize / 5; i++) {
//      canvas.drawLine(
//        Offset(0, leftPress + i * 5.0),
//        Offset(
//          size.width,
//          leftPress + i * 5.0,
//        ),
//        linePaint,
//      );
//    }
  }

  @override
  bool shouldRepaint(QrScanBoxPainter oldDelegate) =>
      animationValue != oldDelegate.animationValue;

  @override
  bool shouldRebuildSemantics(QrScanBoxPainter oldDelegate) =>
      animationValue != oldDelegate.animationValue;
}
