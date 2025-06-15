import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:guideme/Models/Place.dart';

class FirestoreService {
  final String userId;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  FirestoreService({required this.userId});

  // Save a favorite place
  Future<void> saveFavoritePlace(Place place) async {
    try {
      print('Saving favorite: ${place.id} - ${place.name}');
      await _db
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(place.id)
          .set(place.toJson());
    } catch (e) {
      print('Error saving favorite: $e');
      rethrow;
    }
  }

  // Remove a favorite place
  Future<void> removeFavoritePlace(String placeId) async {
    try {
      print('Removing favorite: $placeId');
      await _db
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(placeId)
          .delete();
    } catch (e) {
      print('Error removing favorite: $e');
      rethrow;
    }
  }

  // Get favorite places as a stream
  Stream<List<Place>> getFavoritePlaces() {
    return _db
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .snapshots()
        .map((snapshot) {
      print('Fetched ${snapshot.docs.length} favorites: ${snapshot.docs.map((doc) => doc.id).toList()}');
      return snapshot.docs.map((doc) => Place.fromJson(doc.data())).toList();
    }).handleError((e) {
      print('Error fetching favorites: $e');
    });
  }

  // Save a trip
  Future<void> saveTrip(String tripName, List<Place> places) async {
    try {
      print('Saving trip: $tripName with ${places.length} places');
      await _db.collection('users').doc(userId).collection('trips').add({
        'name': tripName,
        'places': places.map((place) => place.toJson()).toList(),
      });
    } catch (e) {
      print('Error saving trip: $e');
      rethrow;
    }
  }

  // Get trips as a stream
  Stream<List<Map<String, dynamic>>> getTrips() {
    return _db
        .collection('users')
        .doc(userId)
        .collection('trips')
        .snapshots()
        .map((snapshot) {
      print('Fetched ${snapshot.docs.length} trips');
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'name': data['name'] as String,
          'places': (data['places'] as List<dynamic>)
              .map((place) => Place.fromJson(place as Map<String, dynamic>))
              .toList(),
        };
      }).toList();
    }).handleError((e) {
      print('Error fetching trips: $e');
    });
  }

  // Add or update a recent place
  Future<void> addRecentPlace(Place place) async {
    try {
      print('Saving recent place: ${place.id} - ${place.name}');
      final recentPlacesRef = _db
          .collection('users')
          .doc(userId)
          .collection('recent_places')
          .doc(place.id);

      // Get current recent places count
      final recentPlaces = await _db
          .collection('users')
          .doc(userId)
          .collection('recent_places')
          .get();

      // If we have 30 or more places, delete the oldest one
      if (recentPlaces.docs.length >= 30) {
        final oldestPlace = recentPlaces.docs
            .reduce((curr, next) =>
        curr['timestamp'].toDate().isBefore(next['timestamp'].toDate())
            ? curr
            : next);
        await _db
            .collection('users')
            .doc(userId)
            .collection('recent_places')
            .doc(oldestPlace.id)
            .delete();
        print('Removed oldest recent place: ${oldestPlace.id}');
      }

      // Update or add the place with a new timestamp
      await recentPlacesRef.set({
        ...place.toJson(),
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('Successfully saved/updated recent place: ${place.id}');
    } catch (e) {
      print('Error adding recent place: $e');
      rethrow;
    }
  }

  // Get recent places as a stream
  Stream<List<Place>> getRecentPlaces() {
    try {
      return _db
          .collection('users')
          .doc(userId)
          .collection('recent_places')
          .orderBy('timestamp', descending: true)
          .limit(30)
          .snapshots()
          .map((snapshot) {
        print('Fetched ${snapshot.docs.length} recent places: ${snapshot.docs.map((doc) => doc.id).toList()}');
        return snapshot.docs.map((doc) => Place.fromJson(doc.data())).toList();
      }).handleError((e) {
        print('Error fetching recent places: $e');
        return [];
      });
    } catch (e) {
      print('Error setting up recent places stream: $e');
      return Stream.value([]);
    }
  }
}