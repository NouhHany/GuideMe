import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../Models/Place.dart';
import '../../Services/google_places_api.dart';
import '../../Services/wiki_api.dart';
import '../../Services/wiki_summary.dart';

class PlaceDetailsScreen extends StatefulWidget {
  final Place place;

  const PlaceDetailsScreen({Key? key, required this.place}) : super(key: key);

  @override
  _PlaceDetailsScreenState createState() => _PlaceDetailsScreenState();
}

class _PlaceDetailsScreenState extends State<PlaceDetailsScreen>
    with TickerProviderStateMixin {
  final FlutterTts _tts = FlutterTts();
  bool _isPlayingDescription = false;
  late TabController _tabController;
  int _currentImageIndex = 0;
  double _audioProgress = 0.0;
  double _audioDuration = 0.0;
  String? _currentText;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _configureTts();
    _loadEnv();
  }

  Future<void> _loadEnv() async {
    await dotenv.load(fileName: ".env");
  }

  void _configureTts() async {
    await _tts.setLanguage('en-US');
    _tts.setProgressHandler((String text, int startOffset, int endOffset, String word) {
      if (mounted) {
        setState(() {
          _audioProgress = endOffset / text.length;
          _audioDuration = text.length / 50.0;
        });
      }
    });
    _tts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isPlayingDescription = false;
          _audioProgress = 0.0;
          _audioDuration = 0.0;
        });
      }
    });
    _tts.setErrorHandler((msg) {
      if (mounted) {
        setState(() {
          _isPlayingDescription = false;
          _audioProgress = 0.0;
          _audioDuration = 0.0;
        });
      }
    });
  }

  Future<void> _toggleDescriptionAudio(String text) async {
    if (!mounted) return;
    _currentText = text;
    await _tts.stop();
    if (_isPlayingDescription) {
      await _tts.pause();
      setState(() { _isPlayingDescription = false; });
    } else {
      await _tts.speak(text);
      setState(() { _isPlayingDescription = true; });
    }
  }

  Future<void> _seekDescriptionAudio(double value) async {
    if (!mounted || _currentText == null) return;
    final text = _currentText!;
    final newPosition = (value * text.length).toInt().clamp(0, text.length - 1);
    await _tts.stop();
    await _tts.speak(text.substring(newPosition));
    setState(() {
      _audioProgress = value;
      _isPlayingDescription = true;
    });
  }

  bool _isValidNetworkUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  void _changeImage(int delta) {
    final imageList = widget.place.imageUrls.where(_isValidNetworkUrl).toList();
    if (_isValidNetworkUrl(widget.place.imageUrl)) imageList.insert(0, widget.place.imageUrl);
    if (imageList.isNotEmpty) {
      setState(() {
        _currentImageIndex = (_currentImageIndex + delta) % imageList.length;
        if (_currentImageIndex < 0) _currentImageIndex += imageList.length;
      });
    }
  }

  @override
  void dispose() {
    _tts.stop();
    _tabController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _launchDirections() async {
    final lat = widget.place.latitude;
    final lng = widget.place.longitude;
    if (lat == 0 && lng == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid location coordinates')),
      );
      return;
    }
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps')),
      );
    }
  }

  void _moveCameraToPlace() {
    if (_mapController != null && widget.place.latitude != 0 && widget.place.longitude != 0) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(widget.place.latitude, widget.place.longitude),
          14.0,
        ),
      );
    }
  }

  Widget _buildDynamicFields(WikiSummary wikiSummary, String placeType) {
    final metadata = wikiSummary.metadata;
    final theme = Theme.of(context);
    final textScaler = MediaQuery.of(context).textScaler;
    final isDarkMode = theme.brightness == Brightness.dark;

    final fields = <Widget>[];
    if (placeType.contains('monument') || placeType.contains('statue')) {
      if (metadata['height'] != null) {
        fields.add(_buildFieldRow('Height', metadata['height'], theme, textScaler, isDarkMode));
      }
      if (metadata['date_built'] != null) {
        fields.add(_buildFieldRow('Date Built', metadata['date_built'], theme, textScaler, isDarkMode));
      }
      if (metadata['architect'] != null) {
        fields.add(_buildFieldRow('Architect', metadata['architect'], theme, textScaler, isDarkMode));
      }
    } else if (placeType.contains('museum')) {
      if (metadata['architect'] != null) {
        fields.add(_buildFieldRow('Architect', metadata['architect'], theme, textScaler, isDarkMode));
      }
      if (metadata['director'] != null) {
        fields.add(_buildFieldRow('Director', metadata['director'], theme, textScaler, isDarkMode));
      }
      if (metadata['collection_size'] != null) {
        fields.add(_buildFieldRow('Collection Size', metadata['collection_size'], theme, textScaler, isDarkMode));
      }
    } else {
      if (metadata['date_built'] != null) {
        fields.add(_buildFieldRow('Date Built', metadata['date_built'], theme, textScaler, isDarkMode));
      }
      if (metadata['architect'] != null) {
        fields.add(_buildFieldRow('Architect', metadata['architect'], theme, textScaler, isDarkMode));
      }
    }

    return fields.isEmpty
        ? Text(
      '',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: isDarkMode ? Colors.white70 : Colors.black87,
        fontSize: textScaler.scale(14),
      ),
    )
        : Column(children: fields);
  }

  Widget _buildFieldRow(String label, String value, ThemeData theme, TextScaler textScaler, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
              fontSize: textScaler.scale(14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isDarkMode ? Colors.white70 : Colors.black87,
                fontSize: textScaler.scale(14),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final textScaler = MediaQuery.of(context).textScaler;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return SafeArea(
      child: Scaffold(
        body: FutureBuilder<Place>(
          future: widget.place.placeId != null
              ? fetchGooglePlaceDetails(widget.place.placeId!)
              : Future.value(widget.place),
          builder: (context, googleSnapshot) {
            if (googleSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (googleSnapshot.hasError) {
              return const Center(child: Text('Error loading place details'));
            }

            final place = googleSnapshot.data ?? widget.place;
            final imageList = place.imageUrls.where(_isValidNetworkUrl).toList();
            if (_isValidNetworkUrl(place.imageUrl)) imageList.insert(0, place.imageUrl);

            return FutureBuilder<WikiSummary>(
              future: fetchWikipediaSummary(context, widget.place.name),
              builder: (context, wikiSnapshot) {
                if (wikiSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (wikiSnapshot.hasError) {
                  return const Center(child: Text('Error loading summary'));
                }

                final wikiSummary = wikiSnapshot.data ??
                    WikiSummary(title: place.name, extract: 'No summary available', metadata: {});

                final placeType = (place.category.toLowerCase() +
                    (place.subCategory?.toLowerCase() ?? '') +
                    (wikiSummary.description?.toLowerCase() ?? ''))
                    .toLowerCase();
                final descriptionText = place.summary ?? wikiSummary.extract;

                return NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) => [
                    SliverAppBar(
                      expandedHeight: screenHeight * 0.4,
                      floating: false,
                      pinned: true,
                      flexibleSpace: FlexibleSpaceBar(
                        title: Text(
                          place.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: textScaler.scale(18),
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.5),
                                offset: const Offset(1, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            imageList.isNotEmpty
                                ? Image.network(
                              imageList[_currentImageIndex],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 100),
                            )
                                : Container(
                              color: theme.colorScheme.background,
                              child: const Icon(Icons.broken_image, size: 100),
                            ),
                            if (imageList.length > 1)
                              Positioned(
                                left: 16,
                                right: 16,
                                bottom: 16,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.arrow_left, color: Colors.white, size: 32),
                                      onPressed: () => _changeImage(-1),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.arrow_right, color: Colors.white, size: 32),
                                      onPressed: () => _changeImage(1),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  body: Column(
                    children: [
                      TabBar(
                        controller: _tabController,
                        labelColor: const Color(0xFFD4B087),
                        unselectedLabelColor: isDarkMode ? Colors.white70 : Colors.black54,
                        indicatorColor: const Color(0xFFD4B087),
                        tabs: const [Tab(text: 'Details'), Tab(text: 'Map')],
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            ListView(
                              padding: EdgeInsets.all(screenWidth * 0.04),
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        place.name,
                                        style: theme.textTheme.headlineSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          fontSize: textScaler.scale(20),
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        const Icon(Icons.star, color: Colors.amber, size: 20),
                                        SizedBox(width: screenWidth * 0.01),
                                        Text(
                                          place.rating?.toStringAsFixed(1) ?? 'N/A',
                                          style: theme.textTheme.titleMedium?.copyWith(fontSize: textScaler.scale(16)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (place.subCategory != null) ...[
                                  SizedBox(height: screenHeight * 0.01),
                                  Chip(
                                    label: Text(place.subCategory!),
                                    backgroundColor: theme.colorScheme.secondaryContainer,
                                    labelStyle: TextStyle(fontSize: textScaler.scale(12)),
                                  ),
                                ],
                                SizedBox(height: screenHeight * 0.02),
                                Text(
                                  'Description',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: textScaler.scale(18),
                                  ),
                                ),
                                SizedBox(height: screenHeight * 0.01),
                                Text(
                                  descriptionText,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    height: 1.5,
                                    fontSize: textScaler.scale(14),
                                  ),
                                ),
                                SizedBox(height: screenHeight * 0.02),
                                _buildDynamicFields(wikiSummary, placeType),
                                SizedBox(height: screenHeight * 0.02),
                                if (wikiSummary.thumbnailUrl != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      wikiSummary.thumbnailUrl!,
                                      height: 150,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const SizedBox(),
                                    ),
                                  ),
                                SizedBox(height: screenHeight * 0.02),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Slider(
                                        value: _audioProgress,
                                        onChanged: _isPlayingDescription ? _seekDescriptionAudio : null,
                                        activeColor: const Color(0xFFD4B087),
                                        inactiveColor: Colors.grey,
                                        thumbColor: const Color(0xFFD4B087),
                                        min: 0.0,
                                        max: 1.0,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        _isPlayingDescription ? Icons.pause : Icons.play_arrow,
                                        color: const Color(0xFFD4B087),
                                      ),
                                      onPressed: () => _toggleDescriptionAudio(descriptionText),
                                    ),
                                  ],
                                ),
                                SizedBox(height: screenHeight * 0.02),
                                SizedBox(height: screenHeight * 0.02),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.directions, color: Colors.white),
                                  label: const Text('Get Directions', style: TextStyle(color: Colors.white)),
                                  onPressed: _launchDirections,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFFD4B087),
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(
                              height: screenHeight * 0.5,
                              child: GoogleMap(
                                onMapCreated: (GoogleMapController controller) {
                                  _mapController = controller;
                                  _moveCameraToPlace();
                                },
                                initialCameraPosition: CameraPosition(
                                  target: LatLng(widget.place.latitude, widget.place.longitude),
                                  zoom: 14.0,
                                ),
                                markers: {
                                  Marker(
                                    markerId: const MarkerId('place'),
                                    position: LatLng(widget.place.latitude, widget.place.longitude),
                                    infoWindow: InfoWindow(title: widget.place.name),
                                  ),
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}